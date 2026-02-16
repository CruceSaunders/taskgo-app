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

    /// Deduplicated incomplete tasks for display -- batch tasks show only the leader
    var incompleteTasksForDisplay: [TaskItem] {
        var seenBatches = Set<String>()
        var result: [TaskItem] = []
        for task in incompleteTasks {
            if let batchId = task.batchId {
                if !seenBatches.contains(batchId) {
                    seenBatches.insert(batchId)
                    result.append(task)
                }
            } else {
                result.append(task)
            }
        }
        return result
    }

    var completedTasks: [TaskItem] {
        tasks.filter { $0.isComplete }.sorted { ($0.completedAt ?? Date.distantPast) > ($1.completedAt ?? Date.distantPast) }
    }

    /// Deduplicated completed tasks -- batch tasks show only the leader
    var completedTasksForDisplay: [TaskItem] {
        var seenBatches = Set<String>()
        var result: [TaskItem] = []
        for task in completedTasks {
            if let batchId = task.batchId {
                if !seenBatches.contains(batchId) {
                    seenBatches.insert(batchId)
                    result.append(task)
                }
            } else {
                result.append(task)
            }
        }
        return result
    }

    var firstIncompleteTask: TaskItem? {
        incompleteTasksForDisplay.first
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

    func addBatch(names: [String], batchTimeEstimate: Int, groupId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let batchId = UUID().uuidString
        let targetPosition = 1

        do {
            // Shift existing tasks down to make room
            try await firestoreService.shiftTaskPositions(
                groupId: groupId,
                userId: userId,
                fromPosition: targetPosition
            )

            // Create all tasks in the batch with the same batchId
            for (index, name) in names.enumerated() {
                let task = TaskItem(
                    name: name,
                    timeEstimate: batchTimeEstimate / names.count,
                    position: targetPosition,
                    groupId: groupId,
                    batchId: batchId,
                    batchTimeEstimate: index == 0 ? batchTimeEstimate : nil
                )
                _ = try await firestoreService.createTask(task, userId: userId)
            }
            print("[TaskVM] addBatch: created \(names.count) tasks with batchId \(batchId)")
        } catch {
            print("[TaskVM] addBatch error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    /// Batch existing tasks together with a collective time
    func batchTasks(_ taskIds: [String], batchTimeEstimate: Int) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let batchId = UUID().uuidString

        do {
            for (index, taskId) in taskIds.enumerated() {
                guard var task = tasks.first(where: { $0.id == taskId }) else { continue }
                task.batchId = batchId
                task.batchTimeEstimate = index == 0 ? batchTimeEstimate : nil
                try await firestoreService.updateTask(task, userId: userId)
            }
            print("[TaskVM] batchTasks: batched \(taskIds.count) tasks")
        } catch {
            print("[TaskVM] batchTasks error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    /// Unbatch a task (remove from its batch)
    func unbatchTask(_ task: TaskItem) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        var updated = task
        updated.batchId = nil
        updated.batchTimeEstimate = nil

        do {
            try await firestoreService.updateTask(updated, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Get all tasks in a batch
    func tasksInBatch(_ batchId: String) -> [TaskItem] {
        tasks.filter { $0.batchId == batchId }
    }

    /// For Task Go: get the next "item" (single task or batch leader)
    var taskGoItems: [TaskItem] {
        var seen = Set<String>()
        var items: [TaskItem] = []
        for task in incompleteTasks {
            if let batchId = task.batchId {
                if !seen.contains(batchId) {
                    seen.insert(batchId)
                    items.append(task)
                }
            } else {
                items.append(task)
            }
        }
        return items
    }

    /// Force-mark a task as complete (never toggles back). Used by Task Go.
    func markComplete(_ task: TaskItem) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard !task.isComplete else { return }

        // If task is part of a batch, complete all tasks in the batch
        if let batchId = task.batchId {
            await markBatchComplete(batchId: batchId)
            return
        }

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

    /// Complete all tasks in a batch at once
    func markBatchComplete(batchId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let batchTasks = tasksInBatch(batchId)

        for var task in batchTasks {
            guard !task.isComplete else { continue }
            task.isComplete = true
            task.completedAt = Date()
            do {
                try await firestoreService.updateTask(task, userId: userId)
            } catch {
                print("[TaskVM] markBatchComplete error: \(error)")
            }
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

    func moveTaskUp(_ task: TaskItem) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let items = incompleteTasksForDisplay
        guard let index = items.firstIndex(where: { $0.id == task.id }), index > 0 else { return }

        var above = items[index - 1]
        var current = items[index]

        // Ensure unique positions by using index-based values
        above.position = index + 1
        current.position = index

        do {
            try await firestoreService.updateTask(above, userId: userId)
            try await firestoreService.updateTask(current, userId: userId)
        } catch {
            print("[TaskVM] moveTaskUp error: \(error)")
        }
    }

    func moveTaskDown(_ task: TaskItem) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let items = incompleteTasksForDisplay
        guard let index = items.firstIndex(where: { $0.id == task.id }), index < items.count - 1 else { return }

        var below = items[index + 1]
        var current = items[index]

        // Ensure unique positions by using index-based values
        below.position = index + 1
        current.position = index + 2

        do {
            try await firestoreService.updateTask(below, userId: userId)
            try await firestoreService.updateTask(current, userId: userId)
        } catch {
            print("[TaskVM] moveTaskDown error: \(error)")
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
