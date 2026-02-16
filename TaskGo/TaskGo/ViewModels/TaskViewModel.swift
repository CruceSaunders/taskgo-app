import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class TaskViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private var listener: ListenerRegistration?

    var incompleteTasks: [TaskItem] {
        tasks.filter { !$0.isComplete }.sorted { $0.position < $1.position }
    }

    var completedTasks: [TaskItem] {
        tasks.filter { $0.isComplete }.sorted { ($0.completedAt ?? Date.distantPast) > ($1.completedAt ?? Date.distantPast) }
    }

    var firstIncompleteTask: TaskItem? {
        incompleteTasks.first
    }

    func startListening(groupId: String) {
        stopListening()
        guard let userId = Auth.auth().currentUser?.uid else { return }

        listener = firestoreService.listenToTasks(userId: userId, groupId: groupId) { [weak self] tasks in
            Task { @MainActor in
                self?.tasks = tasks
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func addTask(name: String, timeEstimate: Int, description: String? = nil, position: Int? = nil, groupId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[TaskVM] addTask: no authenticated user")
            return
        }

        let targetPosition = position ?? 1
        print("[TaskVM] addTask: '\(name)' at position \(targetPosition) in group \(groupId)")

        do {
            try await firestoreService.shiftTaskPositions(
                groupId: groupId,
                userId: userId,
                fromPosition: targetPosition
            )

            let task = TaskItem(
                name: name,
                description: description,
                timeEstimate: timeEstimate,
                position: targetPosition,
                groupId: groupId
            )

            let taskId = try await firestoreService.createTask(task, userId: userId)
            print("[TaskVM] addTask: created with id \(taskId)")
        } catch {
            print("[TaskVM] addTask error: \(error)")
            errorMessage = error.localizedDescription
            ErrorHandler.shared.handle(error)
        }
    }

    /// Force-mark a task as complete (never toggles back). Used by Task Go.
    func markComplete(_ task: TaskItem) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard !task.isComplete else { return }

        var updated = task
        updated.isComplete = true
        updated.completedAt = Date()

        do {
            try await firestoreService.updateTask(updated, userId: userId)
        } catch {
            print("[TaskVM] markComplete error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func toggleComplete(_ task: TaskItem) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[TaskVM] toggleComplete: no user")
            return
        }

        var updated = task
        updated.isComplete.toggle()
        updated.completedAt = updated.isComplete ? Date() : nil
        print("[TaskVM] toggleComplete: '\(task.name)' -> isComplete=\(updated.isComplete)")

        do {
            try await firestoreService.updateTask(updated, userId: userId)
        } catch {
            print("[TaskVM] toggleComplete error: \(error)")
            errorMessage = error.localizedDescription
            ErrorHandler.shared.handle(error)
        }
    }

    func updateTask(_ task: TaskItem) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            try await firestoreService.updateTask(task, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTask(_ task: TaskItem) async {
        guard let userId = Auth.auth().currentUser?.uid,
              let taskId = task.id else { return }

        do {
            try await firestoreService.deleteTask(taskId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveTask(from source: IndexSet, to destination: Int) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        var reordered = incompleteTasks
        reordered.move(fromOffsets: source, toOffset: destination)

        do {
            for (index, var task) in reordered.enumerated() {
                let newPosition = index + 1
                if task.position != newPosition {
                    task.position = newPosition
                    try await firestoreService.updateTask(task, userId: userId)
                }
            }
        } catch {
            print("[TaskVM] moveTask error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func reorderTask(_ task: TaskItem, to newPosition: Int, groupId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            // Shift tasks at new position down
            try await firestoreService.shiftTaskPositions(
                groupId: groupId,
                userId: userId,
                fromPosition: newPosition
            )

            var updated = task
            updated.position = newPosition
            try await firestoreService.updateTask(updated, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
