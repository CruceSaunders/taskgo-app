import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class GroupViewModel: ObservableObject {
    @Published var groups: [TaskGroup] = []
    @Published var selectedGroupId: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private var listener: ListenerRegistration?

    var selectedGroup: TaskGroup? {
        groups.first { $0.id == selectedGroupId }
    }

    func startListening() {
        stopListening()
        guard let userId = Auth.auth().currentUser?.uid else { return }

        listener = firestoreService.listenToGroups(userId: userId) { [weak self] groups in
            Task { @MainActor in
                self?.groups = groups
                // Auto-select the first group if none selected
                if self?.selectedGroupId == nil, let firstGroup = groups.first {
                    self?.selectedGroupId = firstGroup.id
                }
                // If selected group was deleted, select the first one
                if let selectedId = self?.selectedGroupId,
                   !groups.contains(where: { $0.id == selectedId }),
                   let firstGroup = groups.first {
                    self?.selectedGroupId = firstGroup.id
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
        guard let userId = Auth.auth().currentUser?.uid else { return }

        var updated = group
        updated.name = newName

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
            try await firestoreService.deleteGroup(groupId, userId: userId)
            // Select the default group after deletion
            if selectedGroupId == groupId {
                selectedGroupId = groups.first { $0.isDefault }?.id ?? groups.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectGroup(_ group: TaskGroup) {
        selectedGroupId = group.id
    }
}
