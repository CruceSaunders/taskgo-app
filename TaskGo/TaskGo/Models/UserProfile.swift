import Foundation
import FirebaseFirestore

struct UserProfile: Identifiable, Codable {
    @DocumentID var id: String?
    var email: String
    var username: String
    var displayName: String
    var totalXP: Int
    var level: Int
    var weeklyXP: Int
    var weeklyXPResetDate: Date
    var createdAt: Date

    init(
        id: String? = nil,
        email: String,
        username: String,
        displayName: String,
        totalXP: Int = 0,
        level: Int = 1,
        weeklyXP: Int = 0,
        weeklyXPResetDate: Date = UserProfile.nextMondayMidnight(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.username = username
        self.displayName = displayName
        self.totalXP = totalXP
        self.level = level
        self.weeklyXP = weeklyXP
        self.weeklyXPResetDate = weeklyXPResetDate
        self.createdAt = createdAt
    }

    /// Calculate the next Monday at midnight for weekly XP reset
    static func nextMondayMidnight() -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = 2 // Monday
        components.hour = 0
        components.minute = 0
        components.second = 0
        guard let nextMonday = calendar.date(from: components) else { return now }
        return nextMonday > now ? nextMonday : calendar.date(byAdding: .weekOfYear, value: 1, to: nextMonday) ?? now
    }
}
