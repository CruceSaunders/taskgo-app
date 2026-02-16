import SwiftUI

struct TaskRowView: View {
    @EnvironmentObject var taskVM: TaskViewModel
    let task: TaskItem

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // If this is a batch leader, show the batch header
            if task.isBatched, let batchId = task.batchId {
                batchView(batchId: batchId)
            } else {
                singleTaskRow
            }
        }
    }

    private var singleTaskRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if !task.isComplete {
                    Text("\(task.position)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }

                Button(action: {
                    Task { await taskVM.toggleComplete(task) }
                }) {
                    Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(task.isComplete ? Color.calmTeal : .primary.opacity(0.4))
                }
                .buttonStyle(.plain)

                Text(task.name)
                    .font(.system(size: 13, weight: .regular))
                    .strikethrough(task.isComplete)
                    .foregroundStyle(task.isComplete ? .secondary : .primary)
                    .lineLimit(1)

                Spacer()

                if !task.isComplete {
                    Text(task.timeEstimateFormatted)
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.45))
                }

                if task.description != nil {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Reorder buttons (incomplete only)
                if !task.isComplete {
                    VStack(spacing: 0) {
                        Button(action: {
                            Task { await taskVM.moveTaskUp(task) }
                        }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.primary.opacity(0.3))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            Task { await taskVM.moveTaskDown(task) }
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.primary.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button(action: {
                    Task { await taskVM.deleteTask(task) }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())

            if isExpanded, let description = task.description {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.65))
                    .padding(.horizontal, 48)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func batchView(batchId: String) -> some View {
        let batchTasks = taskVM.tasksInBatch(batchId)
        let allComplete = batchTasks.allSatisfy { $0.isComplete }
        let batchTime = task.batchTimeEstimate ?? task.timeEstimate
        let batchMinutes = batchTime / 60

        return VStack(alignment: .leading, spacing: 0) {
            // Batch header
            HStack(spacing: 8) {
                if !allComplete {
                    Text("\(task.position)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }

                Image(systemName: allComplete ? "checkmark.square.stack.fill" : "square.stack")
                    .font(.system(size: 14))
                    .foregroundStyle(allComplete ? Color.calmTeal : Color.calmTeal.opacity(0.7))

                Text("Batch (\(batchTasks.count) tasks)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(allComplete ? .secondary : .primary)

                Spacer()

                if !allComplete {
                    Text("\(batchMinutes)m")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.45))
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)

            // Expanded: show individual sub-tasks
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(batchTasks) { subTask in
                        HStack(spacing: 6) {
                            Image(systemName: subTask.isComplete ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
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
    }
}
