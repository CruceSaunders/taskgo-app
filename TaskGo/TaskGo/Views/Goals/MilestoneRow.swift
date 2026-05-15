import SwiftUI

struct MilestoneRow: View {
    @EnvironmentObject var goalVM: GoalViewModel
    let goal: Goal
    let milestone: Milestone

    @State private var isEditing: Bool = false
    @State private var editText: String = ""
    @State private var hovered: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                goalVM.toggleMilestoneComplete(goal, milestoneId: milestone.id)
            }) {
                Image(systemName: milestone.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(milestone.isComplete ? Color.calmTeal : .secondary.opacity(0.6))
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("Step", text: $editText, onCommit: commit)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit(commit)
            } else {
                Text(milestone.title)
                    .font(.system(size: 12))
                    .strikethrough(milestone.isComplete)
                    .foregroundStyle(milestone.isComplete ? .secondary : .primary)
                    .onTapGesture(count: 2) { startEditing() }
            }

            Spacer()

            if milestone.isComplete, let completed = milestone.completedAt {
                Text(completed, format: .relative(presentation: .named))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if hovered && !isEditing {
                Button(action: startEditing) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Button(action: {
                    goalVM.deleteMilestone(goal, milestoneId: milestone.id)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(hovered ? Color.secondary.opacity(0.06) : Color.clear)
        .cornerRadius(4)
        .onHover { hovered = $0 }
    }

    private func startEditing() {
        editText = milestone.title
        isEditing = true
    }

    private func commit() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != milestone.title {
            goalVM.renameMilestone(goal, milestoneId: milestone.id, to: trimmed)
        }
        isEditing = false
    }
}
