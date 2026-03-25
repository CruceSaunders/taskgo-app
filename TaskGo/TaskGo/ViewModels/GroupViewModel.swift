import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class GroupViewModel: ObservableObject {
    static let allGroupId = "__all__"

    @Published var groups: [TaskGroup] = []
    @Published var navigationPath: [String] = []
    @Published var showingAllTasks = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private var listener: ListenerRegistration?

    // MARK: - Computed Navigation State

    var currentGroupId: String? {
        navigationPath.last
    }

    var isAtRoot: Bool {
        navigationPath.isEmpty && !showingAllTasks
    }

    var isInsideGroup: Bool {
        !navigationPath.isEmpty
    }

    var selectedGroupId: String? {
        if showingAllTasks { return GroupViewModel.allGroupId }
        return currentGroupId
    }

    var isAllGroupSelected: Bool {
        showingAllTasks
    }

    var selectedGroup: TaskGroup? {
        guard let id = currentGroupId else { return nil }
        return groups.first { $0.id == id }
    }

    var currentGroup: TaskGroup? {
        selectedGroup
    }

    var childGroups: [TaskGroup] {
        let parentId = currentGroupId
        return groups
            .filter { $0.parentId == parentId }
            .sorted { $0.order < $1.order }
    }

    var topLevelGroups: [TaskGroup] {
        groups
            .filter { $0.parentId == nil }
            .sorted { $0.order < $1.order }
    }

    func breadcrumb() -> [TaskGroup] {
        navigationPath.compactMap { id in
            groups.first { $0.id == id }
        }
    }

    // MARK: - Navigation

    func pushGroup(_ group: TaskGroup) {
        guard let id = group.id else { return }
        showingAllTasks = false
        navigationPath.append(id)
    }

    func pushGroupById(_ id: String) {
        showingAllTasks = false
        navigationPath.append(id)
    }

    func popGroup() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    func popToRoot() {
        navigationPath.removeAll()
        showingAllTasks = false
    }

    func selectAllGroup() {
        navigationPath.removeAll()
        showingAllTasks = true
    }

    func selectGroup(_ group: TaskGroup) {
        guard let id = group.id else { return }
        showingAllTasks = false
        navigationPath = [id]
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
                self.navigationPath = self.navigationPath.filter { validIds.contains($0) }
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
            showingAllTasks = false
            if parentId == currentGroupId {
                // Stay in current group -- the new sub-group will appear in childGroups
            } else {
                navigationPath = parentId == nil ? [] : navigationPath
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
            navigationPath = navigationPath.filter { !allIds.contains($0) }
        } catch {
            print("[GroupVM] deleteGroup error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

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
