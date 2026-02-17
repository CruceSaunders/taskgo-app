import Foundation
import SwiftUI
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
    var chainId: String? // tasks with the same chainId form a dependent chain
    var chainOrder: Int? // step number within the chain (1, 2, 3...)
    var colorTag: String? // color name for highlighting
    var groupTitle: String? // title for batch or chain groups ("red", "blue", "green", "yellow", "purple", "orange")

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
        groupTitle: String? = nil
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
