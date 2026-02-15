import Foundation
import FirebaseFirestore

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

    init(
        id: String? = nil,
        name: String,
        description: String? = nil,
        timeEstimate: Int,
        position: Int = 1,
        isComplete: Bool = false,
        groupId: String,
        createdAt: Date = Date(),
        completedAt: Date? = nil
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
    }
}
