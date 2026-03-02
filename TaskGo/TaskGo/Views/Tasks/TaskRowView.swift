import SwiftUI

struct TaskRowView: View {
    @EnvironmentObject var taskVM: TaskViewModel
    @EnvironmentObject var groupVM: GroupViewModel
    let task: TaskItem
    @Binding var editingTaskId: String?
    var displayIndex: Int = 0
    var dragLocked: Bool = false

    @State private var isExpanded = false
    @State private var editName = ""
    @State private var editMinutes = ""
    @State private var editDescription = ""
    @State private var editGroupTitle = ""
    @State private var editBatchMinutes = ""
    @State private var showRecurrenceEdit = false
    @State private var editRecFrequency = "daily"
    @State private var editRecInterval = "1"
    @State private var editRecDaysOfWeek: Set<Int> = []
    @State private var editRecTimes: [String] = ["09:00"]
    @State private var editRecHasEndDate = false
    @State private var editRecEndDate = Date()

    private var isEditing: Bool {
        editingTaskId == task.id
    }

    // Use batchId or chainId as the "group editing" key
    private var groupEditKey: String? {
        task.batchId ?? task.chainId
    }

    private var isGroupEditing: Bool {
        if let key = groupEditKey {
            return editingTaskId == "group:\(key)"
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if task.isChained, let chainId = task.chainId {
                chainView(chainId: chainId)
            } else if task.isBatched, let batchId = task.batchId {
                batchView(batchId: batchId)
            } else {
                singleTaskRow
            }
        }
    }

    // MARK: - Reorder Buttons (shared)

    private var reorderButtons: some View {
        VStack(spacing: 2) {
            Button(action: {
                Task { await taskVM.moveTaskUp(task) }
            }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.35))
                    .frame(width: 22, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: {
                Task { await taskVM.moveTaskDown(task) }
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.35))
                    .frame(width: 22, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Single Task Row

    private var singleTaskRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                editView
            } else {
                displayView
            }
        }
    }

    private var displayView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                // Priority number
                if !task.isComplete && displayIndex > 0 {
                    Text("\(displayIndex)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, alignment: .trailing)
                }

                // Checkbox
                Button(action: {
                    guard !dragLocked else { return }
                    Task { await taskVM.toggleComplete(task) }
                }) {
                    Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17))
                        .foregroundStyle(task.isComplete ? Color.calmTeal : .primary.opacity(0.4))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Tap name to edit
                Button(action: {
                    guard !dragLocked else { return }
                    editName = task.name
                    editMinutes = "\(task.timeEstimate / 60)"
                    editDescription = task.description ?? ""
                    if let rec = task.recurrence {
                        showRecurrenceEdit = true
                        editRecFrequency = rec.frequency
                        editRecInterval = "\(rec.interval)"
                        editRecDaysOfWeek = Set(rec.daysOfWeek ?? [])
                        editRecTimes = rec.timesOfDay
                        editRecHasEndDate = rec.endDate != nil
                        editRecEndDate = rec.endDate ?? Date()
                    } else {
                        showRecurrenceEdit = false
                    }
                    editingTaskId = task.id
                }) {
                    HStack(spacing: 3) {
                        Text(task.name)
                            .font(.system(size: 13))
                            .strikethrough(task.isComplete)
                            .foregroundStyle(task.isComplete ? .secondary : .primary)
                            .lineLimit(2)
                        if task.isRecurring {
                            Image(systemName: "repeat")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.calmTeal.opacity(0.6))
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 4)

                // Right-side actions (fixed width for alignment)
                HStack(spacing: 6) {
                    if !task.isComplete && task.timeEstimate > 0 {
                        Text(task.timeEstimateFormatted)
                            .font(.system(size: 10))
                            .foregroundStyle(.primary.opacity(0.45))
                            .frame(width: 30, alignment: .trailing)
                    }

                    if task.isComplete {
                        Button(action: {
                            Task { await taskVM.toggleComplete(task) }
                        }) {
                            Text("Undo")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.calmTeal)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.calmTeal.opacity(0.1))
                                .cornerRadius(3)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: {
                        guard !dragLocked else { return }
                        Task { await taskVM.deleteTask(task) }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.red.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 20, alignment: .center)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())

            if isExpanded, let description = task.description {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.65))
                    .padding(.leading, 40)
                    .padding(.trailing, 10)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(task.colorTagColor?.opacity(0.1) ?? Color.clear)
    }

    private var editView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                TextField("Task name", text: $editName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                TextField("min", text: $editMinutes)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 40)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)

                Text("m")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.45))
            }

            TextField("Note (optional)", text: $editDescription, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))

            // Move to group
            if groupVM.groups.count > 1 {
                HStack(spacing: 4) {
                    Text("Move to:")
                        .font(.system(size: 9))
                        .foregroundStyle(.primary.opacity(0.4))
                    ForEach(groupVM.groups.filter { $0.id != task.groupId }) { group in
                        Button(action: {
                            Task {
                                await taskVM.moveToGroup(task, newGroupId: group.id ?? "")
                                editingTaskId = nil
                            }
                        }) {
                            Text(group.name)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.calmTeal)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.calmTeal.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Recurrence toggle
            HStack(spacing: 4) {
                Button(action: { showRecurrenceEdit.toggle() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "repeat")
                            .font(.system(size: 9))
                        Text(showRecurrenceEdit ? "Recurring" : "Make recurring")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(showRecurrenceEdit ? Color.calmTeal : .primary.opacity(0.4))
                }
                .buttonStyle(.plain)

                if showRecurrenceEdit && task.isRecurring {
                    Button(action: {
                        showRecurrenceEdit = false
                        Task {
                            await taskVM.updateRecurrence(task, rule: nil)
                        }
                    }) {
                        Text("Remove")
                            .font(.system(size: 9))
                            .foregroundStyle(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }

            if showRecurrenceEdit {
                editRecurrenceSection
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    editingTaskId = nil
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                if !task.isComplete {
                    HStack(spacing: 4) {
                        Button(action: { Task { await taskVM.moveTaskUp(task) } }) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 10))
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                        .buttonStyle(.plain)

                        Button(action: { Task { await taskVM.moveTaskDown(task) } }) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 10))
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button(action: {
                    Task {
                        await taskVM.duplicateTask(task)
                        editingTaskId = nil
                    }
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Save") {
                    var updated = task
                    updated.name = editName
                    updated.timeEstimate = (Int(editMinutes) ?? task.timeEstimate / 60) * 60
                    updated.description = editDescription.isEmpty ? nil : editDescription

                    let newRule: RecurrenceRule? = showRecurrenceEdit ? RecurrenceRule(
                        frequency: editRecFrequency,
                        interval: Int(editRecInterval) ?? 1,
                        daysOfWeek: (editRecFrequency == "weekly" || editRecFrequency == "custom") && !editRecDaysOfWeek.isEmpty ? Array(editRecDaysOfWeek) : nil,
                        timesOfDay: editRecTimes.filter { !$0.isEmpty },
                        endDate: editRecHasEndDate ? editRecEndDate : nil
                    ) : nil

                    Task {
                        await taskVM.updateTask(updated)
                        await taskVM.updateRecurrence(updated, rule: newRule)
                        editingTaskId = nil
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.borderedProminent)
                .tint(Color.calmTeal)
                .controlSize(.small)
                .disabled(editName.isEmpty)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.calmTeal.opacity(0.05))
    }

    private var editRecurrenceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(["daily", "weekly", "custom"], id: \.self) { freq in
                    Button(action: { editRecFrequency = freq }) {
                        Text(freq.capitalized)
                            .font(.system(size: 9, weight: editRecFrequency == freq ? .semibold : .regular))
                            .foregroundStyle(editRecFrequency == freq ? .white : .primary.opacity(0.5))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(editRecFrequency == freq ? Color.calmTeal : Color.secondary.opacity(0.08))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 3) {
                Text("Every")
                    .font(.system(size: 9))
                    .foregroundStyle(.primary.opacity(0.5))
                TextField("1", text: $editRecInterval)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 25)
                    .font(.system(size: 9))
                    .multilineTextAlignment(.center)
                Text(editRecFrequency == "weekly" ? "week(s)" : "day(s)")
                    .font(.system(size: 9))
                    .foregroundStyle(.primary.opacity(0.5))
            }

            if editRecFrequency == "weekly" || editRecFrequency == "custom" {
                HStack(spacing: 2) {
                    ForEach([(1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")], id: \.0) { day, label in
                        Button(action: {
                            if editRecDaysOfWeek.contains(day) {
                                editRecDaysOfWeek.remove(day)
                            } else {
                                editRecDaysOfWeek.insert(day)
                            }
                        }) {
                            Text(label)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(editRecDaysOfWeek.contains(day) ? .white : .primary.opacity(0.5))
                                .frame(width: 18, height: 18)
                                .background(editRecDaysOfWeek.contains(day) ? Color.calmTeal : Color.secondary.opacity(0.1))
                                .cornerRadius(3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 3) {
                Text("At")
                    .font(.system(size: 9))
                    .foregroundStyle(.primary.opacity(0.5))
                ForEach(editRecTimes.indices, id: \.self) { index in
                    TextField("HH:mm", text: $editRecTimes[index])
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 48)
                        .font(.system(size: 9))
                        .multilineTextAlignment(.center)
                    if editRecTimes.count > 1 {
                        Button(action: { editRecTimes.remove(at: index) }) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 8))
                                .foregroundStyle(.red.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button(action: { editRecTimes.append("09:00") }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.calmTeal)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 3) {
                Toggle("End", isOn: $editRecHasEndDate)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 9))
                    .foregroundStyle(.primary.opacity(0.5))
                if editRecHasEndDate {
                    DatePicker("", selection: $editRecEndDate, displayedComponents: .date)
                        .labelsHidden()
                        .controlSize(.mini)
                }
            }
        }
        .padding(6)
        .background(Color.calmTeal.opacity(0.05))
        .cornerRadius(6)
    }

    // MARK: - Batch View

    private func batchView(batchId: String) -> some View {
        let batchTasks = taskVM.tasksInBatch(batchId)
        let allComplete = batchTasks.allSatisfy { $0.isComplete }
        let batchTime = batchTasks.compactMap({ $0.batchTimeEstimate }).first ?? task.timeEstimate
        let batchMinutes = batchTime / 60

        return VStack(alignment: .leading, spacing: 0) {
            if isGroupEditing {
                // Edit mode for batch
                groupEditView(
                    title: batchTasks.compactMap({ $0.groupTitle }).first ?? "",
                    time: batchMinutes,
                    groupId: batchId,
                    isBatch: true,
                    tasks: batchTasks
                )
            } else {
                // Display mode
                HStack(spacing: 8) {
                    if !allComplete && displayIndex > 0 {
                        Text("\(displayIndex)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, alignment: .trailing)
                    }

                    Image(systemName: allComplete ? "checkmark.square.stack.fill" : "square.stack")
                        .font(.system(size: 15))
                        .foregroundStyle(allComplete ? Color.calmTeal : Color.calmTeal.opacity(0.7))

                    // Tap to edit
                    Button(action: {
                        guard !dragLocked else { return }
                        editGroupTitle = batchTasks.compactMap({ $0.groupTitle }).first ?? ""
                        editBatchMinutes = "\(batchMinutes)"
                        editingTaskId = "group:\(batchId)"
                    }) {
                        VStack(alignment: .leading, spacing: 1) {
                            if let title = batchTasks.compactMap({ $0.groupTitle }).first {
                                Text(title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(allComplete ? .secondary : .primary)
                                    .lineLimit(1)
                            }
                            Text("Batch (\(batchTasks.count) tasks)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    HStack(spacing: 6) {
                        if !allComplete {
                            Text("\(batchMinutes)m")
                                .font(.system(size: 10))
                                .foregroundStyle(.primary.opacity(0.45))
                                .frame(width: 30, alignment: .trailing)
                        }

                        Button(action: {
                            Task {
                                for subTask in batchTasks {
                                    await taskVM.deleteTask(subTask)
                                }
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(.red.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .frame(width: 20, alignment: .center)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }

            // Sub-tasks always visible and editable
            VStack(spacing: 0) {
                ForEach(batchTasks) { subTask in
                    SubTaskRow(subTask: subTask, editingTaskId: $editingTaskId, taskVM: taskVM, accentColor: Color.calmTeal)
                }
            }
            .padding(.bottom, 4)
        }
    }
    

    // MARK: - Chain View

    private func chainView(chainId: String) -> some View {
        ChainGroupView(
            chainId: chainId,
            task: task,
            editingTaskId: $editingTaskId,
            displayIndex: displayIndex,
            dragLocked: dragLocked,
            editGroupTitle: $editGroupTitle,
            editBatchMinutes: $editBatchMinutes,
            isGroupEditing: isGroupEditing,
            groupEditViewBuilder: { title, time, gid, tasks in
                groupEditView(title: title, time: time, groupId: gid, isBatch: false, tasks: tasks)
            }
        )
    }

    // MARK: - Group Edit View (shared for batch and chain)

    private func groupEditView(title: String, time: Int, groupId: String, isBatch: Bool, tasks: [TaskItem]) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                TextField(isBatch ? "Batch title" : "Chain title", text: $editGroupTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                if isBatch {
                    TextField("min", text: $editBatchMinutes)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 40)
                        .font(.system(size: 11))
                        .multilineTextAlignment(.center)
                    Text("m")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.45))
                }
            }

            // Move to group
            if groupVM.groups.count > 1, let currentGroupId = tasks.first?.groupId {
                HStack(spacing: 4) {
                    Text("Move to:")
                        .font(.system(size: 9))
                        .foregroundStyle(.primary.opacity(0.4))
                    ForEach(groupVM.groups.filter { $0.id != currentGroupId }) { group in
                        Button(action: {
                            if let firstTask = tasks.first {
                                Task {
                                    await taskVM.moveToGroup(firstTask, newGroupId: group.id ?? "")
                                    editingTaskId = nil
                                }
                            }
                        }) {
                            Text(group.name)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(isBatch ? Color.calmTeal : .orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background((isBatch ? Color.calmTeal : Color.orange).opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    editingTaskId = nil
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                // Duplicate
                Button(action: {
                    Task {
                        if isBatch {
                            await taskVM.duplicateBatch(batchId: groupId)
                        } else {
                            await taskVM.duplicateChain(chainId: groupId)
                        }
                        editingTaskId = nil
                    }
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Save") {
                    Task {
                        // Update title on the first task that has groupTitle, or the first task
                        if let firstTask = tasks.first {
                            var updated = firstTask
                            updated.groupTitle = editGroupTitle.isEmpty ? nil : editGroupTitle
                            if isBatch {
                                updated.batchTimeEstimate = (Int(editBatchMinutes) ?? time) * 60
                            }
                            await taskVM.updateTask(updated)
                        }
                        editingTaskId = nil
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.borderedProminent)
                .tint(isBatch ? Color.calmTeal : .orange)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background((isBatch ? Color.calmTeal : Color.orange).opacity(0.05))
    }
}

// MARK: - Chain Group View (with drag reorder for steps)

struct ChainGroupView<GroupEdit: View>: View {
    @EnvironmentObject var taskVM: TaskViewModel
    @EnvironmentObject var groupVM: GroupViewModel

    let chainId: String
    let task: TaskItem
    @Binding var editingTaskId: String?
    var displayIndex: Int
    var dragLocked: Bool
    @Binding var editGroupTitle: String
    @Binding var editBatchMinutes: String
    var isGroupEditing: Bool
    var groupEditViewBuilder: (String, Int, String, [TaskItem]) -> GroupEdit

    @State private var draggingStepId: String?
    @State private var stepDragOffset: CGFloat = 0
    @State private var stepTargetIndex: Int?
    @State private var stepStartIndex: Int?
    @State private var stepRowHeight: CGFloat = 30

    var body: some View {
        let chainTasks = taskVM.tasksInChain(chainId)
        let allComplete = chainTasks.allSatisfy { $0.isComplete }
        let completedCount = chainTasks.filter { $0.isComplete }.count
        let totalMinutes = chainTasks.reduce(0) { $0 + $1.timeEstimate } / 60

        VStack(alignment: .leading, spacing: 0) {
            if isGroupEditing {
                groupEditViewBuilder(
                    chainTasks.compactMap({ $0.groupTitle }).first ?? "",
                    totalMinutes,
                    chainId,
                    chainTasks
                )
            } else {
                HStack(spacing: 8) {
                    if !allComplete && displayIndex > 0 {
                        Text("\(displayIndex)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, alignment: .trailing)
                    }

                    Image(systemName: allComplete ? "link.circle.fill" : "link")
                        .font(.system(size: 15))
                        .foregroundStyle(allComplete ? .orange : .orange.opacity(0.7))

                    Button(action: {
                        guard !dragLocked else { return }
                        editGroupTitle = chainTasks.compactMap({ $0.groupTitle }).first ?? ""
                        editBatchMinutes = "\(totalMinutes)"
                        editingTaskId = "group:\(chainId)"
                    }) {
                        VStack(alignment: .leading, spacing: 1) {
                            if let title = chainTasks.compactMap({ $0.groupTitle }).first {
                                Text(title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(allComplete ? .secondary : .primary)
                                    .lineLimit(1)
                            }
                            Text("Chain (\(chainTasks.count) steps)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if !allComplete {
                        Text("\(completedCount)/\(chainTasks.count)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(4)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        if !allComplete {
                            Text("\(totalMinutes)m")
                                .font(.system(size: 10))
                                .foregroundStyle(.primary.opacity(0.45))
                                .frame(width: 30, alignment: .trailing)
                        }

                        Button(action: {
                            Task {
                                for t in chainTasks { await taskVM.deleteTask(t) }
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(.red.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .frame(width: 20, alignment: .center)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
            }

            VStack(spacing: 0) {
                ForEach(Array(chainTasks.enumerated()), id: \.element.id) { stepIndex, step in
                    let isDraggingStep = draggingStepId == step.id

                    SubTaskRow(
                        subTask: step,
                        editingTaskId: $editingTaskId,
                        taskVM: taskVM,
                        accentColor: .orange,
                        showStepNumber: true,
                        showTime: true
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                if geo.size.height > 10 { stepRowHeight = geo.size.height }
                            }
                        }
                    )
                    .offset(y: isDraggingStep ? stepDragOffset : 0)
                    .zIndex(isDraggingStep ? 100 : 0)
                    .opacity(isDraggingStep ? 0.85 : 1.0)
                    .shadow(color: isDraggingStep ? .black.opacity(0.12) : .clear, radius: isDraggingStep ? 3 : 0, y: isDraggingStep ? 1 : 0)
                    .background(isDraggingStep ? Color(.windowBackgroundColor) : Color.clear)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { value in
                                if draggingStepId == nil {
                                    draggingStepId = step.id
                                    stepStartIndex = stepIndex
                                }
                                guard draggingStepId == step.id else { return }
                                stepDragOffset = value.translation.height
                                let rowsMoved = Int(round(stepDragOffset / max(stepRowHeight, 28)))
                                let newIdx = min(max(stepIndex + rowsMoved, 0), chainTasks.count - 1)
                                stepTargetIndex = newIdx
                            }
                            .onEnded { _ in
                                if let startIdx = stepStartIndex,
                                   let targetIdx = stepTargetIndex,
                                   startIdx != targetIdx {
                                    Task {
                                        await taskVM.reorderChainStep(chainId: chainId, from: startIdx, to: targetIdx)
                                    }
                                }
                                withAnimation(.easeOut(duration: 0.15)) {
                                    draggingStepId = nil
                                    stepDragOffset = 0
                                    stepTargetIndex = nil
                                    stepStartIndex = nil
                                }
                            }
                    )
                }
            }
            .padding(.bottom, 4)
        }
    }
}

// MARK: - Editable Sub-Task Row (for batch and chain sub-tasks)

struct SubTaskRow: View {
    let subTask: TaskItem
    @Binding var editingTaskId: String?
    var taskVM: TaskViewModel
    var accentColor: Color = .calmTeal
    var showStepNumber: Bool = false
    var showTime: Bool = false

    @State private var editName = ""
    @State private var editMinutes = ""

    private var isEditing: Bool {
        editingTaskId == subTask.id
    }

    var body: some View {
        if isEditing {
            // Edit mode
            HStack(spacing: 6) {
                if showStepNumber {
                    Text("\(subTask.chainOrder ?? 0).")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(accentColor)
                        .frame(width: 20, alignment: .trailing)
                }

                TextField("Task name", text: $editName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))

                TextField("min", text: $editMinutes)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 35)
                    .font(.system(size: 10))
                    .multilineTextAlignment(.center)

                Button("Save") {
                    var updated = subTask
                    updated.name = editName
                    updated.timeEstimate = (Int(editMinutes) ?? subTask.timeEstimate / 60) * 60
                    Task {
                        await taskVM.updateTask(updated)
                        editingTaskId = nil
                    }
                }
                .font(.system(size: 9, weight: .semibold))
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .controlSize(.mini)

                Button(action: { editingTaskId = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, showStepNumber ? 32 : 48)
            .padding(.vertical, 4)
            .background(accentColor.opacity(0.05))
        } else {
            // Display mode -- tap to edit
            HStack(spacing: 6) {
                if showStepNumber {
                    Text("\(subTask.chainOrder ?? 0).")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(subTask.isComplete ? .secondary : accentColor)
                        .frame(width: 20, alignment: .trailing)
                }

                Button(action: {
                    Task { await taskVM.toggleComplete(subTask) }
                }) {
                    Image(systemName: subTask.isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundColor(subTask.isComplete ? accentColor : .primary.opacity(0.3))
                }
                .buttonStyle(.plain)

                Button(action: {
                    editName = subTask.name
                    editMinutes = "\(subTask.timeEstimate / 60)"
                    editingTaskId = subTask.id
                }) {
                    Text(subTask.name)
                        .font(.system(size: 11))
                        .strikethrough(subTask.isComplete)
                        .foregroundStyle(subTask.isComplete ? .secondary : .primary)
                        .lineLimit(2)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 6) {
                    if showTime {
                        Text("\(subTask.timeEstimate / 60)m")
                            .font(.system(size: 9))
                            .foregroundStyle(.primary.opacity(0.4))
                            .frame(width: 30, alignment: .trailing)
                    }

                    Button(action: {
                        Task { await taskVM.deleteTask(subTask) }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 20, alignment: .center)
                }
            }
            .padding(.horizontal, showStepNumber ? 32 : 48)
            .padding(.vertical, 3)
        }
    }
}
