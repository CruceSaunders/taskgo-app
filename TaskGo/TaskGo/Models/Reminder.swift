import Foundation
import FirebaseFirestore

struct Reminder: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var title: String
    var note: String?
    var scheduledDate: Date
    var repeatRule: String // "none", "daily", "weekly", "monthly"
    var soundEnabled: Bool
    var isComplete: Bool
    var createdAt: Date

    init(
        id: String? = nil,
        title: String,
        note: String? = nil,
        scheduledDate: Date,
        repeatRule: String = "none",
        soundEnabled: Bool = true,
        isComplete: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.scheduledDate = scheduledDate
        self.repeatRule = repeatRule
        self.soundEnabled = soundEnabled
        self.isComplete = isComplete
        self.createdAt = createdAt
    }

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: scheduledDate)
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: scheduledDate)
    }

    var repeatLabel: String {
        switch repeatRule {
        case "daily": return "Daily"
        case "weekly": return "Weekly"
        case "monthly": return "Monthly"
        default: return ""
        }
    }

    var isUpcoming: Bool {
        !isComplete && scheduledDate > Date().addingTimeInterval(-60)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(scheduledDate)
    }
}
