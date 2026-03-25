import Foundation
import FirebaseFirestore

struct TaskGroup: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var order: Int
    var isDefault: Bool
    var parentId: String?
    var createdAt: Date

    init(
        id: String? = nil,
        name: String,
        order: Int = 0,
        isDefault: Bool = false,
        parentId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.isDefault = isDefault
        self.parentId = parentId
        self.createdAt = createdAt
    }
}
