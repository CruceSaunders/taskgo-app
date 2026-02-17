import SwiftUI

struct TaskRowView: View {
    @EnvironmentObject var taskVM: TaskViewModel
    let task: TaskItem
    @Binding var editingTaskId: String?
    var displayIndex: Int = 0

    @State private var isExpanded = false
    @State private var editName = ""
    @State private var editMinutes = ""
    @State private var editDescription = ""

    private var isEditing: Bool {
        editingTaskId == task.id
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
                    editName = task.name
                    editMinutes = "\(task.timeEstimate / 60)"
                    editDescription = task.description ?? ""
                    editingTaskId = task.id
                }) {
                    Text(task.name)
                        .font(.system(size: 13))
                        .strikethrough(task.isComplete)
                        .foregroundStyle(task.isComplete ? .secondary : .primary)
                        .lineLimit(2)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 4)

                if !task.isComplete {
                    Text(task.timeEstimateFormatted)
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.45))
                        .fixedSize()

                    // Reorder arrows
                    VStack(spacing: 0) {
                        Button(action: { Task { await taskVM.moveTaskUp(task) } }) {
                            Image(systemName: "arrowtriangle.up.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.primary.opacity(0.35))
                                .frame(width: 22, height: 16)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button(action: { Task { await taskVM.moveTaskDown(task) } }) {
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.primary.opacity(0.35))
                                .frame(width: 22, height: 16)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Duplicate
                Button(action: {
                    Task { await taskVM.duplicateTask(task) }
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Trash
                Button(action: {
                    Task { await taskVM.deleteTask(task) }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.4))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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

            HStack(spacing: 12) {
                Button("Cancel") {
                    editingTaskId = nil
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                // Reorder in edit mode
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

                Spacer()

                Button("Save") {
                    var updated = task
                    updated.name = editName
                    updated.timeEstimate = (Int(editMinutes) ?? task.timeEstimate / 60) * 60
                    updated.description = editDescription.isEmpty ? nil : editDescription
                    Task {
                        await taskVM.updateTask(updated)
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

    // MARK: - Batch View

    private func batchView(batchId: String) -> some View {
        let batchTasks = taskVM.tasksInBatch(batchId)
        let allComplete = batchTasks.allSatisfy { $0.isComplete }
        let batchTime = batchTasks.compactMap({ $0.batchTimeEstimate }).first ?? task.timeEstimate
        let batchMinutes = batchTime / 60

        return VStack(alignment: .leading, spacing: 0) {
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

                Text("Batch (\(batchTasks.count) tasks)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(allComplete ? .secondary : .primary)

                Spacer()

                if !allComplete {
                    Text("\(batchMinutes)m")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.45))
                        .fixedSize()
                }

                // Duplicate batch
                Button(action: {
                    Task { await taskVM.duplicateBatch(batchId: batchId) }
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Delete entire batch
                Button(action: {
                    Task {
                        for subTask in batchTasks {
                            await taskVM.deleteTask(subTask)
                        }
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.5))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)

            // Sub-tasks always visible
            VStack(spacing: 0) {
                ForEach(batchTasks) { subTask in
                    HStack(spacing: 6) {
                            Image(systemName: subTask.isComplete ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 13))
                                .foregroundStyle(subTask.isComplete ? Color.calmTeal : .primary.opacity(0.3))

                            Text(subTask.name)
                                .font(.system(size: 11))
                                .strikethrough(subTask.isComplete)
                                .foregroundStyle(subTask.isComplete ? .secondary : .primary)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, 48)
                        .padding(.vertical, 3)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    

    // MARK: - Chain View

    private func chainView(chainId: String) -> some View {
        let chainTasks = taskVM.tasksInChain(chainId)
        let allComplete = chainTasks.allSatisfy { $0.isComplete }
        let completedCount = chainTasks.filter { $0.isComplete }.count
        let totalMinutes = chainTasks.reduce(0) { $0 + $1.timeEstimate } / 60

        return VStack(alignment: .leading, spacing: 0) {
            // Chain header with priority number
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

                Text("Chain")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(allComplete ? .secondary : .primary)

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

                if !allComplete {
                    Text("\(totalMinutes)m")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.45))
                        .fixedSize()
                }

                // Duplicate chain
                Button(action: {
                    Task { await taskVM.duplicateChain(chainId: chainId) }
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: {
                    Task {
                        for t in chainTasks { await taskVM.deleteTask(t) }
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.5))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)

            // Steps -- always visible
            VStack(spacing: 0) {
                ForEach(chainTasks) { step in
                    HStack(spacing: 6) {
                        Text("\(step.chainOrder ?? 0).")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(step.isComplete ? .secondary : .orange)
                            .frame(width: 20, alignment: .trailing)

                        Image(systemName: step.isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13))
                            .foregroundColor(step.isComplete ? .orange : .primary.opacity(0.3))

                        Text(step.name)
                            .font(.system(size: 12))
                            .strikethrough(step.isComplete)
                            .foregroundStyle(step.isComplete ? .secondary : .primary)
                            .lineLimit(2)

                        Spacer()

                        Text("\(step.timeEstimate / 60)m")
                            .font(.system(size: 9))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 3)
                }
            }
            .padding(.bottom, 4)
        }
    }
}
