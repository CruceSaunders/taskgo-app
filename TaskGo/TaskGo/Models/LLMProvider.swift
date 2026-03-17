import Foundation

enum LLMProvider: String, CaseIterable, Codable, Identifiable {
    case openai = "openai"
    case anthropic = "anthropic"
    case groq = "groq"
    case openrouter = "openrouter"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .groq: return "Groq"
        case .openrouter: return "OpenRouter"
        }
    }

    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4o-mini"
        case .anthropic: return "claude-sonnet-4-20250514"
        case .groq: return "llama-3.3-70b-versatile"
        case .openrouter: return "openai/gpt-4o-mini"
        }
    }

    var baseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .anthropic: return "https://api.anthropic.com/v1/messages"
        case .groq: return "https://api.groq.com/openai/v1/chat/completions"
        case .openrouter: return "https://openrouter.ai/api/v1/chat/completions"
        }
    }

    var isOpenAICompatible: Bool {
        switch self {
        case .openai, .groq, .openrouter: return true
        case .anthropic: return false
        }
    }

    var supportsJSONMode: Bool {
        switch self {
        case .openai, .groq: return true
        case .anthropic, .openrouter: return false
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openai: return "sk-proj-..."
        case .anthropic: return "sk-ant-..."
        case .groq: return "gsk_..."
        case .openrouter: return "sk-or-..."
        }
    }

    static var selectedProvider: LLMProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: "llmProvider") ?? "openai"
            return LLMProvider(rawValue: raw) ?? .openai
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "llmProvider")
        }
    }

    static var selectedModel: String? {
        get { UserDefaults.standard.string(forKey: "llmModel") }
        set { UserDefaults.standard.set(newValue, forKey: "llmModel") }
    }

    static var effectiveModel: String {
        selectedModel?.isEmpty == false ? selectedModel! : selectedProvider.defaultModel
    }

    static var currentAPIKey: String? {
        KeychainService.getAPIKey(for: selectedProvider.rawValue)
    }

    static var isConfigured: Bool {
        currentAPIKey != nil
    }
}
