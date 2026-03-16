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

    enum CodingKeys: String, CodingKey {
        case id, email, username, displayName, totalXP, level, weeklyXP
        case weeklyXPResetDate, createdAt
    }

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decode(String.self, forKey: .displayName)
        totalXP = try container.decode(Int.self, forKey: .totalXP)
        level = try container.decode(Int.self, forKey: .level)
        weeklyXP = try container.decode(Int.self, forKey: .weeklyXP)
        weeklyXPResetDate = try container.decode(Date.self, forKey: .weeklyXPResetDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    static func nextMondayMidnight() -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = 2
        components.hour = 0
        components.minute = 0
        components.second = 0
        guard let nextMonday = calendar.date(from: components) else { return now }
        return nextMonday > now ? nextMonday : calendar.date(byAdding: .weekOfYear, value: 1, to: nextMonday) ?? now
    }
}
