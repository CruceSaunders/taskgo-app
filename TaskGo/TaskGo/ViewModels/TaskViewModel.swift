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
    private var pendingToggleIds = Set<String>()

    var incompleteTasks: [TaskItem] {
        tasks.filter { !$0.isComplete }.sorted { $0.position < $1.position }
    }

    /// Deduplicated incomplete tasks for display -- batch/chain groups show only the leader
    var incompleteTasksForDisplay: [TaskItem] {
        var seenGroups = Set<String>()
        var result: [TaskItem] = []
        for task in incompleteTasks {
            if let batchId = task.batchId {
                if !seenGroups.contains("b:\(batchId)") {
                    seenGroups.insert("b:\(batchId)")
                    result.append(task)
                }
            } else if let chainId = task.chainId {
                if !seenGroups.contains("c:\(chainId)") {
                    seenGroups.insert("c:\(chainId)")
                    // Use the first task in chain order as the leader
                    if let leader = tasksInChain(chainId).first {
                        result.append(leader)
                    } else {
                        result.append(task)
                    }
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

    /// Deduplicated completed tasks
    var completedTasksForDisplay: [TaskItem] {
        var seenGroups = Set<String>()
        var result: [TaskItem] = []
        for task in completedTasks {
            if let batchId = task.batchId {
                if !seenGroups.contains("b:\(batchId)") {
                    seenGroups.insert("b:\(batchId)")
                    result.append(task)
                }
            } else if let chainId = task.chainId {
                if !seenGroups.contains("c:\(chainId)") {
                    seenGroups.insert("c:\(chainId)")
                    let chainTasks = tasksInChain(chainId)
                    let allComplete = chainTasks.allSatisfy { $0.isComplete }
                    if allComplete, let leader = chainTasks.first {
                        result.append(leader)
                    }
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
                guard let self = self else { return }
                // Preserve local state for tasks with pending toggle operations
                if self.pendingToggleIds.isEmpty {
                    self.tasks = tasks
                } else {
                    var merged = tasks
                    for (i, task) in merged.enumerated() {
                        if let id = task.id, self.pendingToggleIds.contains(id),
                           let localTask = self.tasks.first(where: { $0.id == id }) {
                            merged[i].isComplete = localTask.isComplete
                            merged[i].completedAt = localTask.completedAt
                        }
                    }
                    self.tasks = merged
                }
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

    func addBatch(names: [String], batchTimeEstimate: Int, groupId: String, title: String? = nil) async {
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
                    batchTimeEstimate: index == 0 ? batchTimeEstimate : nil,
                    groupTitle: index == 0 ? title : nil
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

    // MARK: - Chains (Dependent Tasks)

    func addChain(names: [String], times: [Int], groupId: String, title: String? = nil) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let chainId = UUID().uuidString
        let targetPosition = 1

        do {
            try await firestoreService.shiftTaskPositions(
                groupId: groupId,
                userId: userId,
                fromPosition: targetPosition
            )

            for (index, name) in names.enumerated() {
                let time = index < times.count ? times[index] : 1500
                let task = TaskItem(
                    name: name,
                    timeEstimate: time,
                    position: targetPosition,
                    groupId: groupId,
                    chainId: chainId,
                    chainOrder: index + 1,
                    groupTitle: index == 0 ? title : nil
                )
                _ = try await firestoreService.createTask(task, userId: userId)
            }
            print("[TaskVM] addChain: created \(names.count) steps with chainId \(chainId)")
        } catch {
            print("[TaskVM] addChain error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func chainTasks(_ taskIds: [String]) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let chainId = UUID().uuidString

        do {
            for (index, taskId) in taskIds.enumerated() {
                guard var task = tasks.first(where: { $0.id == taskId }) else { continue }
                task.chainId = chainId
                task.chainOrder = index + 1
                try await firestoreService.updateTask(task, userId: userId)
            }
            print("[TaskVM] chainTasks: chained \(taskIds.count) tasks")
        } catch {
            print("[TaskVM] chainTasks error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func unchainTask(_ task: TaskItem) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        var updated = task
        updated.chainId = nil
        updated.chainOrder = nil
        do {
            try await firestoreService.updateTask(updated, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func tasksInChain(_ chainId: String) -> [TaskItem] {
        tasks.filter { $0.chainId == chainId }
            .sorted { ($0.chainOrder ?? 0) < ($1.chainOrder ?? 0) }
    }

    func nextIncompleteChainStep(_ chainId: String) -> TaskItem? {
        tasksInChain(chainId).first { !$0.isComplete }
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

    /// Mark a single task complete (ignoring batch/chain grouping). Used for chain steps.
    func markSingleComplete(_ task: TaskItem) async {
        guard let userId = Auth.auth().currentUser?.uid,
              let taskId = task.id else { return }
        guard !task.isComplete else { return }

        do {
            try await firestoreService.updateTaskFields(
                taskId: taskId,
                fields: ["isComplete": true, "completedAt": Date()],
                userId: userId
            )
        } catch {
            print("[TaskVM] markSingleComplete error: \(error)")
            errorMessage = error.localizedDescription
        }
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
        guard let userId = Auth.auth().currentUser?.uid,
              let taskId = task.id else {
            return
        }

        let newComplete = !task.isComplete

        // Lock this task ID so the listener doesn't overwrite our local change
        pendingToggleIds.insert(taskId)

        // Optimistic local update for instant UI
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[index].isComplete = newComplete
            tasks[index].completedAt = newComplete ? Date() : nil
        }

        do {
            var data: [String: Any] = ["isComplete": newComplete]
            if newComplete {
                data["completedAt"] = Date()
            } else {
                data["completedAt"] = FieldValue.delete()
            }
            try await firestoreService.updateTaskFields(taskId: taskId, fields: data, userId: userId)
        } catch {
            print("[TaskVM] toggleComplete error: \(error)")
            // Revert on failure
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[index].isComplete = !newComplete
                tasks[index].completedAt = !newComplete ? Date() : nil
            }
            errorMessage = error.localizedDescription
        }

        // Unlock after a delay to let the confirmed listener fire
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.pendingToggleIds.remove(taskId)
        }
    }

    func moveToGroup(_ task: TaskItem, newGroupId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // Move individual task
        if !task.isGrouped {
            var updated = task
            updated.groupId = newGroupId
            updated.position = 1
            try? await firestoreService.updateTask(updated, userId: userId)
            return
        }

        // Move entire batch
        if let batchId = task.batchId {
            for var t in tasksInBatch(batchId) {
                t.groupId = newGroupId
                try? await firestoreService.updateTask(t, userId: userId)
            }
            return
        }

        // Move entire chain
        if let chainId = task.chainId {
            for var t in tasksInChain(chainId) {
                t.groupId = newGroupId
                try? await firestoreService.updateTask(t, userId: userId)
            }
            return
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

    func setColorTag(_ taskIds: [String], color: String?) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        for taskId in taskIds {
            guard var task = tasks.first(where: { $0.id == taskId }) else { continue }
            let newColor: String?
            if color == nil {
                newColor = nil
            } else {
                newColor = task.colorTag == color ? nil : color
            }
            task.colorTag = newColor
            // Use FieldValue.delete() for nil since merge:true doesn't clear nil optionals
            if newColor == nil {
                try? await firestoreService.removeField("colorTag", taskId: taskId, userId: userId)
            } else {
                try? await firestoreService.updateTask(task, userId: userId)
            }
        }
    }

    // MARK: - Duplicate

    func duplicateTask(_ task: TaskItem) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let newTask = TaskItem(
            name: task.name,
            description: task.description,
            timeEstimate: task.timeEstimate,
            position: task.position + 1,
            groupId: task.groupId,
            colorTag: task.colorTag
        )
        do {
            try await firestoreService.shiftTaskPositions(groupId: task.groupId, userId: userId, fromPosition: newTask.position)
            _ = try await firestoreService.createTask(newTask, userId: userId)
        } catch {
            print("[TaskVM] duplicateTask error: \(error)")
        }
    }

    func duplicateBatch(batchId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let batchTasks = tasksInBatch(batchId)
        guard !batchTasks.isEmpty else { return }

        let newBatchId = UUID().uuidString
        let batchTime = batchTasks.compactMap({ $0.batchTimeEstimate }).first

        do {
            for (index, original) in batchTasks.enumerated() {
                let newTask = TaskItem(
                    name: original.name,
                    description: original.description,
                    timeEstimate: original.timeEstimate,
                    position: (original.position) + batchTasks.count,
                    groupId: original.groupId,
                    batchId: newBatchId,
                    batchTimeEstimate: index == 0 ? batchTime : nil
                )
                _ = try await firestoreService.createTask(newTask, userId: userId)
            }
        } catch {
            print("[TaskVM] duplicateBatch error: \(error)")
        }
    }

    func duplicateChain(chainId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let chainTasks = tasksInChain(chainId)
        guard !chainTasks.isEmpty else { return }

        let newChainId = UUID().uuidString

        do {
            for original in chainTasks {
                let newTask = TaskItem(
                    name: original.name,
                    description: original.description,
                    timeEstimate: original.timeEstimate,
                    position: (original.position) + chainTasks.count,
                    groupId: original.groupId,
                    chainId: newChainId,
                    chainOrder: original.chainOrder
                )
                _ = try await firestoreService.createTask(newTask, userId: userId)
            }
        } catch {
            print("[TaskVM] duplicateChain error: \(error)")
        }
    }

    func deleteTask(_ task: TaskItem) async {
        guard let userId = Auth.auth().currentUser?.uid,
              let taskId = task.id else { return }

        do {
            try await firestoreService.deleteTask(taskId, userId: userId)
            // Renormalize positions after deletion
            await renormalizePositions(groupId: task.groupId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Renormalize task positions to be sequential (1, 2, 3...) with no gaps
    func renormalizePositions(groupId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let items = incompleteTasksForDisplay.filter { $0.groupId == groupId }
        for (index, var task) in items.enumerated() {
            let newPos = index + 1
            if task.position != newPos {
                task.position = newPos
                try? await firestoreService.updateTask(task, userId: userId)
            }
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

        // Use the display list (deduplicated) for reordering
        var reordered = incompleteTasksForDisplay
        reordered.move(fromOffsets: source, toOffset: destination)

        do {
            for (index, var task) in reordered.enumerated() {
                let newPosition = index + 1
                if task.position != newPosition {
                    task.position = newPosition
                    try await firestoreService.updateTask(task, userId: userId)
                    
                    // Also update all tasks in the same batch/chain
                    if let batchId = task.batchId {
                        for var bt in tasksInBatch(batchId) where bt.id != task.id {
                            bt.position = newPosition
                            try await firestoreService.updateTask(bt, userId: userId)
                        }
                    }
                    if let chainId = task.chainId {
                        for var ct in tasksInChain(chainId) where ct.id != task.id {
                            ct.position = newPosition
                            try await firestoreService.updateTask(ct, userId: userId)
                        }
                    }
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
