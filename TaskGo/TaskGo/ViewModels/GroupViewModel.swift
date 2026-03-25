import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class GroupViewModel: ObservableObject {
    static let allGroupId = "__all__"

    @Published var groups: [TaskGroup] = []
    @Published var expandedGroupIds: Set<String> = []
    @Published var showingAllTasks = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private var listener: ListenerRegistration?

    // MARK: - Computed State

    var isAllGroupSelected: Bool {
        showingAllTasks
    }

    var selectedGroupId: String? {
        if showingAllTasks { return GroupViewModel.allGroupId }
        return nil
    }

    var topLevelGroups: [TaskGroup] {
        groups
            .filter { $0.parentId == nil }
            .sorted { $0.order < $1.order }
    }

    func childGroups(of parentId: String) -> [TaskGroup] {
        groups
            .filter { $0.parentId == parentId }
            .sorted { $0.order < $1.order }
    }

    func group(byId id: String) -> TaskGroup? {
        groups.first { $0.id == id }
    }

    var hasExpandedGroups: Bool {
        !expandedGroupIds.isEmpty
    }

    // MARK: - Inline Expand/Collapse

    func toggleGroup(_ groupId: String) {
        if expandedGroupIds.contains(groupId) {
            expandedGroupIds.remove(groupId)
        } else {
            expandedGroupIds.insert(groupId)
        }
        showingAllTasks = false
    }

    func isExpanded(_ groupId: String) -> Bool {
        expandedGroupIds.contains(groupId)
    }

    func collapseAll() {
        expandedGroupIds.removeAll()
    }

    func selectAllGroup() {
        showingAllTasks = true
    }

    func deselectAllGroup() {
        showingAllTasks = false
    }

    // MARK: - Listening

    func startListening() {
        stopListening()
        guard let userId = Auth.auth().currentUser?.uid else { return }

        listener = firestoreService.listenToGroups(userId: userId) { [weak self] groups in
            Task { @MainActor in
                guard let self else { return }
                self.groups = groups
                let validIds = Set(groups.compactMap(\.id))
                self.expandedGroupIds = self.expandedGroupIds.filter { validIds.contains($0) }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - CRUD

    func addGroup(name: String, parentId: String? = nil) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let siblingCount = groups.filter { $0.parentId == parentId }.count
        let group = TaskGroup(name: name, order: siblingCount, parentId: parentId)

        do {
            let groupId = try await firestoreService.createGroup(group, userId: userId)
            if let parentId {
                expandedGroupIds.insert(parentId)
            }
            _ = groupId
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameGroup(_ group: TaskGroup, to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let userId = Auth.auth().currentUser?.uid else { return }

        var updated = group
        updated.name = trimmed

        do {
            try await firestoreService.updateGroup(updated, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteGroup(_ group: TaskGroup) async {
        guard let userId = Auth.auth().currentUser?.uid,
              let groupId = group.id,
              !group.isDefault else { return }

        do {
            let descendantIds = collectDescendantIds(of: groupId)
            let allIds = [groupId] + descendantIds
            for id in allIds {
                try await firestoreService.deleteGroup(id, userId: userId)
            }
            for id in allIds {
                expandedGroupIds.remove(id)
            }
        } catch {
            print("[GroupVM] deleteGroup error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Move Group (drag-and-drop nesting)

    func moveGroupInto(groupId: String, newParentId: String?) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard groupId != newParentId else { return }

        if let newParentId {
            let descendants = collectDescendantIds(of: groupId)
            if descendants.contains(newParentId) { return }
        }

        guard var group = groups.first(where: { $0.id == groupId }) else { return }
        let siblingCount = groups.filter { $0.parentId == newParentId }.count
        group.parentId = newParentId
        group.order = siblingCount

        do {
            try await firestoreService.updateGroup(group, userId: userId)
            if let newParentId {
                expandedGroupIds.insert(newParentId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func collectDescendantIds(of parentId: String) -> [String] {
        let children = groups.filter { $0.parentId == parentId }
        var result: [String] = []
        for child in children {
            if let childId = child.id {
                result.append(childId)
                result.append(contentsOf: collectDescendantIds(of: childId))
            }
        }
        return result
    }
}
