import Foundation

// MARK: - Request/Response Types

struct ScheduleTaskInput: Encodable {
    let objectiveId: String
    let title: String
    let durationMinutes: Int
}

struct ExistingEventInput: Encodable {
    let title: String
    let startTime: String  // "HH:mm"
    let endTime: String    // "HH:mm"
}

struct ScheduledBlock: Decodable, Equatable {
    let objectiveId: String
    let title: String
    let startTime: String  // "HH:mm"
    let endTime: String    // "HH:mm"
}

struct AIScheduleResponse: Decodable {
    let schedule: [ScheduledBlock]
}

// MARK: - Service

class AISchedulerService {
    static let shared = AISchedulerService()
    private init() {}

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o-mini"

    func generateSchedule(
        tasks: [ScheduleTaskInput],
        existingEvents: [ExistingEventInput],
        officeHoursStart: String,
        officeHoursEnd: String,
        dateLabel: String
    ) async throws -> [ScheduledBlock] {
        guard !tasks.isEmpty else { return [] }

        let systemPrompt = """
        You are a time-block scheduler. Given tasks with durations and available time windows, produce an optimal schedule as JSON.

        Rules:
        1. Schedule ALL tasks. Never omit any.
        2. No overlaps with existing events or other tasks.
        3. All tasks must fall within the office hours window.
        4. Add 5-minute buffers between consecutive tasks when space permits.
        5. Prefer placing tasks that require longer focus earlier in the day.
        6. Return ONLY valid JSON matching this exact schema:
        {"schedule": [{"objectiveId": "string", "title": "string", "startTime": "HH:mm", "endTime": "HH:mm"}]}
        7. Times must be in 24-hour "HH:mm" format.
        8. The schedule array must contain exactly one entry per task provided.
        """

        let userPayload = buildUserMessage(
            tasks: tasks,
            existingEvents: existingEvents,
            officeHoursStart: officeHoursStart,
            officeHoursEnd: officeHoursEnd,
            dateLabel: dateLabel
        )

        let requestBody: [String: Any] = [
            "model": model,
            "response_format": ["type": "json_object"],
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPayload]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(Secrets.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AISchedulerError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw AISchedulerError.apiError(httpResponse.statusCode, body)
        }

        let parsed = try parseResponse(data: data)

        if let validationError = validateSchedule(parsed, tasks: tasks, officeHoursStart: officeHoursStart, officeHoursEnd: officeHoursEnd, existingEvents: existingEvents) {
            print("[AIScheduler] Validation failed: \(validationError). Using sequential fallback.")
            return sequentialFallback(tasks: tasks, existingEvents: existingEvents, officeHoursStart: officeHoursStart, officeHoursEnd: officeHoursEnd)
        }

        return parsed
    }

    // MARK: - Message Building

    private func buildUserMessage(
        tasks: [ScheduleTaskInput],
        existingEvents: [ExistingEventInput],
        officeHoursStart: String,
        officeHoursEnd: String,
        dateLabel: String
    ) -> String {
        var parts: [String] = []
        parts.append("Date: \(dateLabel)")
        parts.append("Office hours: \(officeHoursStart) to \(officeHoursEnd)")

        if !existingEvents.isEmpty {
            parts.append("Existing events (do NOT schedule over these):")
            for event in existingEvents {
                parts.append("  - \"\(event.title)\" from \(event.startTime) to \(event.endTime)")
            }
        } else {
            parts.append("No existing events.")
        }

        parts.append("Tasks to schedule:")
        for task in tasks {
            parts.append("  - id: \"\(task.objectiveId)\", title: \"\(task.title)\", duration: \(task.durationMinutes) minutes")
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Response Parsing

    private func parseResponse(data: Data) throws -> [ScheduledBlock] {
        struct OpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String?
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let openAIResp = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = openAIResp.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else {
            throw AISchedulerError.malformedResponse("No content in response")
        }

        let schedule = try JSONDecoder().decode(AIScheduleResponse.self, from: contentData)
        return schedule.schedule
    }

    // MARK: - Validation

    private func validateSchedule(
        _ blocks: [ScheduledBlock],
        tasks: [ScheduleTaskInput],
        officeHoursStart: String,
        officeHoursEnd: String,
        existingEvents: [ExistingEventInput]
    ) -> String? {
        let taskIds = Set(tasks.map(\.objectiveId))
        let blockIds = Set(blocks.map(\.objectiveId))

        if taskIds != blockIds {
            let missing = taskIds.subtracting(blockIds)
            return "Missing tasks: \(missing.joined(separator: ", "))"
        }

        let ohStart = timeToMinutes(officeHoursStart)
        let ohEnd = timeToMinutes(officeHoursEnd)

        for block in blocks {
            let bStart = timeToMinutes(block.startTime)
            let bEnd = timeToMinutes(block.endTime)

            guard bStart != nil && bEnd != nil else {
                return "Invalid time format in block \(block.objectiveId)"
            }

            if bStart! < ohStart! || bEnd! > ohEnd! {
                return "Block \(block.objectiveId) outside office hours"
            }

            if bEnd! <= bStart! {
                return "Block \(block.objectiveId) has end <= start"
            }
        }

        let allBlocks = blocks.map { (start: timeToMinutes($0.startTime)!, end: timeToMinutes($0.endTime)!) }
        for i in 0..<allBlocks.count {
            for j in (i+1)..<allBlocks.count {
                if allBlocks[i].start < allBlocks[j].end && allBlocks[j].start < allBlocks[i].end {
                    return "Overlap between blocks"
                }
            }
        }

        let existingRanges = existingEvents.compactMap { event -> (start: Int, end: Int)? in
            guard let s = timeToMinutes(event.startTime), let e = timeToMinutes(event.endTime) else { return nil }
            return (s, e)
        }
        for block in allBlocks {
            for existing in existingRanges {
                if block.start < existing.end && existing.start < block.end {
                    return "Block conflicts with existing event"
                }
            }
        }

        return nil
    }

    // MARK: - Sequential Fallback

    func sequentialFallback(
        tasks: [ScheduleTaskInput],
        existingEvents: [ExistingEventInput],
        officeHoursStart: String,
        officeHoursEnd: String
    ) -> [ScheduledBlock] {
        let ohStart = timeToMinutes(officeHoursStart) ?? 540
        let ohEnd = timeToMinutes(officeHoursEnd) ?? 1020

        let busyRanges = existingEvents.compactMap { event -> (start: Int, end: Int)? in
            guard let s = timeToMinutes(event.startTime), let e = timeToMinutes(event.endTime) else { return nil }
            return (s, e)
        }.sorted { $0.start < $1.start }

        var freeWindows: [(start: Int, end: Int)] = []
        var cursor = ohStart
        for busy in busyRanges {
            let busyStart = max(busy.start, ohStart)
            let busyEnd = min(busy.end, ohEnd)
            if cursor < busyStart {
                freeWindows.append((cursor, busyStart))
            }
            cursor = max(cursor, busyEnd)
        }
        if cursor < ohEnd {
            freeWindows.append((cursor, ohEnd))
        }

        var result: [ScheduledBlock] = []
        var windowIdx = 0
        var windowCursor = freeWindows.isEmpty ? ohStart : freeWindows[0].start

        for task in tasks {
            while windowIdx < freeWindows.count {
                let window = freeWindows[windowIdx]
                let availableInWindow = window.end - windowCursor
                if availableInWindow >= task.durationMinutes {
                    let block = ScheduledBlock(
                        objectiveId: task.objectiveId,
                        title: task.title,
                        startTime: minutesToTime(windowCursor),
                        endTime: minutesToTime(windowCursor + task.durationMinutes)
                    )
                    result.append(block)
                    windowCursor = windowCursor + task.durationMinutes + 5
                    if windowCursor > window.end {
                        windowIdx += 1
                        if windowIdx < freeWindows.count {
                            windowCursor = freeWindows[windowIdx].start
                        }
                    }
                    break
                } else {
                    windowIdx += 1
                    if windowIdx < freeWindows.count {
                        windowCursor = freeWindows[windowIdx].start
                    }
                }
            }
        }

        return result
    }

    // MARK: - Time Helpers

    private func timeToMinutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    private func minutesToTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%02d:%02d", h, m)
    }
}

// MARK: - Errors

enum AISchedulerError: LocalizedError {
    case networkError(String)
    case apiError(Int, String)
    case malformedResponse(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let msg): return "Network error: \(msg)"
        case .apiError(let code, let body): return "API error (\(code)): \(body)"
        case .malformedResponse(let msg): return "Invalid AI response: \(msg)"
        }
    }
}
