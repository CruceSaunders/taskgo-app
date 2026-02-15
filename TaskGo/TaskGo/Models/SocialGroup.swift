import Foundation
import FirebaseFirestore

struct SocialGroup: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var hostUserId: String
    var createdAt: Date

    init(
        id: String? = nil,
        name: String,
        hostUserId: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.hostUserId = hostUserId
        self.createdAt = createdAt
    }
}

struct SocialGroupMember: Identifiable, Codable {
    @DocumentID var id: String?
    var joinedAt: Date
    var role: String // "host" or "member"
    var weeklyXP: Int
    var displayName: String
    var username: String
    var level: Int

    init(
        id: String? = nil,
        joinedAt: Date = Date(),
        role: String = "member",
        weeklyXP: Int = 0,
        displayName: String = "",
        username: String = "",
        level: Int = 1
    ) {
        self.id = id
        self.joinedAt = joinedAt
        self.role = role
        self.weeklyXP = weeklyXP
        self.displayName = displayName
        self.username = username
        self.level = level
    }
}

struct GroupInvite: Identifiable, Codable {
    @DocumentID var id: String?
    var groupId: String
    var groupName: String
    var invitedBy: String
    var invitedByUsername: String
    var createdAt: Date
    var status: String // "pending", "accepted", "declined"

    init(
        id: String? = nil,
        groupId: String,
        groupName: String,
        invitedBy: String,
        invitedByUsername: String,
        createdAt: Date = Date(),
        status: String = "pending"
    ) {
        self.id = id
        self.groupId = groupId
        self.groupName = groupName
        self.invitedBy = invitedBy
        self.invitedByUsername = invitedByUsername
        self.createdAt = createdAt
        self.status = status
    }
}
