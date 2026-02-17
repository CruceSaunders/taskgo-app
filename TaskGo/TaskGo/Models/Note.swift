import Foundation
import FirebaseFirestore

struct Note: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var date: String // "2026-02-16" format
    var content: String
    var updatedAt: Date

    init(
        id: String? = nil,
        date: String,
        content: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.content = content
        self.updatedAt = updatedAt
    }

    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let d = formatter.date(from: date) else { return date }

        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return display.string(from: d)
    }

    var isToday: Bool {
        date == Note.todayString
    }

    static var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
