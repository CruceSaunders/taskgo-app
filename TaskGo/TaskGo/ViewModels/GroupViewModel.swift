import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class GroupViewModel: ObservableObject {
    static let allGroupId = "__all__"

    @Published var groups: [TaskGroup] = []
    @Published var selectedGroupId: String? = GroupViewModel.allGroupId
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private var listener: ListenerRegistration?

    var isAllGroupSelected: Bool {
        selectedGroupId == GroupViewModel.allGroupId
    }

    var selectedGroup: TaskGroup? {
        if isAllGroupSelected { return nil }
        return groups.first { $0.id == selectedGroupId }
    }

    func startListening() {
        stopListening()
        guard let userId = Auth.auth().currentUser?.uid else { return }

        listener = firestoreService.listenToGroups(userId: userId) { [weak self] groups in
            Task { @MainActor in
                self?.groups = groups
                if self?.selectedGroupId == nil {
                    self?.selectedGroupId = GroupViewModel.allGroupId
                }
                if let selectedId = self?.selectedGroupId,
                   selectedId != GroupViewModel.allGroupId,
                   !groups.contains(where: { $0.id == selectedId }) {
                    self?.selectedGroupId = GroupViewModel.allGroupId
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func addGroup(name: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let order = groups.count
        let group = TaskGroup(name: name, order: order)

        do {
            let groupId = try await firestoreService.createGroup(group, userId: userId)
            selectedGroupId = groupId
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
              !group.isDefault else {
            print("[GroupVM] deleteGroup guard failed: userId=\(Auth.auth().currentUser?.uid ?? "nil"), groupId=\(group.id ?? "nil"), isDefault=\(group.isDefault)")
            return
        }

        do {
            try await firestoreService.deleteGroup(groupId, userId: userId)
            // Select the default group after deletion
            if selectedGroupId == groupId {
                selectedGroupId = groups.first { $0.isDefault }?.id ?? groups.first?.id
            }
        } catch {
            print("[GroupVM] deleteGroup error: \(error)")
            errorMessage = error.localizedDescription
            ErrorHandler.shared.handle(error)
        }
    }

    func selectGroup(_ group: TaskGroup) {
        selectedGroupId = group.id
    }

    func selectAllGroup() {
        selectedGroupId = GroupViewModel.allGroupId
    }
}
