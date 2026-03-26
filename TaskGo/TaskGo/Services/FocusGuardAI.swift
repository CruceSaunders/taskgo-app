import Foundation

enum FocusGuardError: Error {
    case noAPIKey
    case apiError(String)
    case captureError
}

class FocusGuardAI {
    static func analyze(prompt: String, imageData: Data) async throws -> String {
        let provider = LLMProvider.selectedProvider
        guard let apiKey = LLMProvider.currentAPIKey else {
            throw FocusGuardError.noAPIKey
        }

        let model = UserDefaults.standard.string(forKey: "focusGuard_model").flatMap({ $0.isEmpty ? nil : $0 })
            ?? provider.defaultModel

        let base64Image = imageData.base64EncodedString()

        if provider == .anthropic {
            return try await callAnthropic(prompt: prompt, base64Image: base64Image, model: model, apiKey: apiKey)
        } else {
            return try await callOpenAICompatible(prompt: prompt, base64Image: base64Image, model: model, apiKey: apiKey, baseURL: provider.baseURL)
        }
    }

    private static func callAnthropic(prompt: String, base64Image: String, model: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 10,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw FocusGuardError.apiError("Anthropic returned status \(status)")
        }

        struct AnthropicResponse: Decodable {
            struct ContentBlock: Decodable { let text: String? }
            let content: [ContentBlock]
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return decoded.content.first?.text ?? "ON_TASK"
    }

    private static func callOpenAICompatible(prompt: String, base64Image: String, model: String, apiKey: String, baseURL: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw FocusGuardError.apiError("Invalid base URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 10,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw FocusGuardError.apiError("Provider returned status \(status)")
        }

        struct OpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return decoded.choices.first?.message.content ?? "ON_TASK"
    }
}
