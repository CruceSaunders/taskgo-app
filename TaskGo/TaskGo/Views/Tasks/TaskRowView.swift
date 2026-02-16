import SwiftUI

struct TaskRowView: View {
    @EnvironmentObject var taskVM: TaskViewModel
    let task: TaskItem

    @State private var isExpanded = false
    @State private var showActions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                // Position number
                if !task.isComplete {
                    Text("\(task.position)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }

                // Checkbox
                Button(action: {
                    Task { await taskVM.toggleComplete(task) }
                }) {
                    Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(task.isComplete ? Color.calmTeal : .primary.opacity(0.4))
                }
                .buttonStyle(.plain)

                // Task info
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.system(size: 13, weight: .regular))
                        .strikethrough(task.isComplete)
                        .foregroundStyle(task.isComplete ? .secondary : .primary)
                        .lineLimit(1)

                    if task.description != nil || !task.isComplete {
                        HStack(spacing: 6) {
                            Label(task.timeEstimateFormatted, systemImage: "clock")
                                .font(.system(size: 10))
                                .foregroundStyle(.primary.opacity(0.55))

                            if task.description != nil {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 6) {
                    // Expand description
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

                    // Delete button
                    Button(action: {
                        Task { await taskVM.deleteTask(task) }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())

            // Expanded description
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
}
