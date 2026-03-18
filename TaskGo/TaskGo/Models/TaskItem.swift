import Foundation
import SwiftUI
import FirebaseFirestore

struct RecurrenceRule: Codable, Equatable {
    var frequency: String       // "daily", "weekly", "monthly", "custom"
    var interval: Int           // e.g. every 2 days, every 3 weeks
    var daysOfWeek: [Int]?      // 1=Sun..7=Sat (for weekly/custom)
    var timesOfDay: [String]    // ["09:00", "14:30"] -- HH:mm format
    var endDate: Date?

    init(
        frequency: String = "daily",
        interval: Int = 1,
        daysOfWeek: [Int]? = nil,
        timesOfDay: [String] = ["09:00"],
        endDate: Date? = nil
    ) {
        self.frequency = frequency
        self.interval = interval
        self.daysOfWeek = daysOfWeek
        self.timesOfDay = timesOfDay
        self.endDate = endDate
    }

    var summaryLabel: String {
        var parts: [String] = []
        switch frequency {
        case "daily":
            parts.append(interval == 1 ? "Daily" : "Every \(interval) days")
        case "weekly":
            if let days = daysOfWeek, !days.isEmpty {
                let names = days.sorted().compactMap { dayAbbreviation($0) }
                parts.append(interval == 1 ? "Weekly" : "Every \(interval) weeks")
                parts.append(names.joined(separator: ", "))
            } else {
                parts.append(interval == 1 ? "Weekly" : "Every \(interval) weeks")
            }
        case "monthly":
            parts.append(interval == 1 ? "Monthly" : "Every \(interval) months")
        case "custom":
            if let days = daysOfWeek, !days.isEmpty {
                let names = days.sorted().compactMap { dayAbbreviation($0) }
                parts.append(names.joined(separator: ", "))
            } else {
                parts.append("Custom")
            }
        default:
            parts.append(frequency.capitalized)
        }
        if !timesOfDay.isEmpty {
            parts.append("at \(timesOfDay.joined(separator: ", "))")
        }
        return parts.joined(separator: " ")
    }

    private func dayAbbreviation(_ day: Int) -> String? {
        switch day {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return nil
        }
    }
}

struct TaskItem: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var description: String?
    var timeEstimate: Int // in seconds
    var position: Int
    var isComplete: Bool
    var groupId: String
    var createdAt: Date
    var completedAt: Date?
    var batchId: String? // tasks with the same batchId are a batch
    var batchTimeEstimate: Int? // collective time override for the batch (seconds)
    var chainId: String? // tasks with the same chainId form a dependent chain
    var chainOrder: Int? // step number within the chain (1, 2, 3...)
    var colorTag: String? // color name for highlighting
    var groupTitle: String? // title for batch or chain groups ("red", "blue", "green", "yellow", "purple", "orange")
    var recurrence: RecurrenceRule?
    var nextOccurrence: Date?

    var timeEstimateFormatted: String {
        let minutes = timeEstimate / 60
        let seconds = timeEstimate % 60
        if seconds == 0 {
            return "\(minutes)m"
        }
        return "\(minutes)m \(seconds)s"
    }

    var timeEstimateMinutes: Int {
        timeEstimate / 60
    }

    var isBatched: Bool {
        batchId != nil
    }

    var isChained: Bool {
        chainId != nil
    }

    var isGrouped: Bool {
        isBatched || isChained
    }

    /// Effective time for Task Go -- uses batch time if part of a batch, else individual
    var effectiveTimeEstimate: Int {
        batchTimeEstimate ?? timeEstimate
    }

    var isRecurring: Bool {
        recurrence != nil
    }

    init(
        id: String? = nil,
        name: String,
        description: String? = nil,
        timeEstimate: Int,
        position: Int = 1,
        isComplete: Bool = false,
        groupId: String,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        batchId: String? = nil,
        batchTimeEstimate: Int? = nil,
        chainId: String? = nil,
        chainOrder: Int? = nil,
        colorTag: String? = nil,
        groupTitle: String? = nil,
        recurrence: RecurrenceRule? = nil,
        nextOccurrence: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.timeEstimate = timeEstimate
        self.position = position
        self.isComplete = isComplete
        self.groupId = groupId
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.batchId = batchId
        self.batchTimeEstimate = batchTimeEstimate
        self.chainId = chainId
        self.chainOrder = chainOrder
        self.colorTag = colorTag
        self.groupTitle = groupTitle
        self.recurrence = recurrence
        self.nextOccurrence = nextOccurrence
    }

    var colorTagColor: Color? {
        guard let tag = colorTag else { return nil }
        switch tag {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        case "teal": return .teal
        default: return nil
        }
    }
}
