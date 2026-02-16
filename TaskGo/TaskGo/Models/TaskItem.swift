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
    var batchId: String? // tasks with the same batchId are a batch
    var batchTimeEstimate: Int? // collective time override for the batch (seconds)

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

    /// Effective time for Task Go -- uses batch time if part of a batch, else individual
    var effectiveTimeEstimate: Int {
        batchTimeEstimate ?? timeEstimate
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
        batchTimeEstimate: Int? = nil
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
    }
}
