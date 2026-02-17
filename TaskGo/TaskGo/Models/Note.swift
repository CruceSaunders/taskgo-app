import Foundation
import FirebaseFirestore

struct Note: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var date: String // "2026-02-16" format
    var content: String // plain text (for search/backwards compat)
    var rtfData: String? // Base64-encoded RTF data (rich text)
    var updatedAt: Date

    init(
        id: String? = nil,
        date: String,
        content: String = "",
        rtfData: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.content = content
        self.rtfData = rtfData
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
