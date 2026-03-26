import SwiftUI

struct FocusTabView: View {
    @EnvironmentObject var focusVM: FocusGuardViewModel
    @EnvironmentObject var taskVM: TaskViewModel
    @EnvironmentObject var groupVM: GroupViewModel

    var body: some View {
        ZStack {
            if focusVM.service.isActive {
                FocusActiveView()
            } else {
                setupView
            }

            if focusVM.showingSummary, let summary = focusVM.lastSummary {
                FocusSummaryView(summary: summary)
            }
        }
        .onAppear {
            if taskVM.tasks.isEmpty {
                taskVM.startListeningAll()
            }
        }
    }

    // MARK: - Setup View

    private var setupView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Focus Guard")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if !LLMProvider.isConfigured {
                    Text("Set AI key in Profile")
                        .font(.system(size: 9))
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select a task to focus on")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    taskSelector

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Context (optional)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.5))
                        TextEditor(text: $focusVM.contextText)
                            .font(.system(size: 11))
                            .frame(height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(alignment: .topLeading) {
                                if focusVM.contextText.isEmpty {
                                    Text("e.g. I'll be on Chrome for research and Terminal for coding...")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.primary.opacity(0.25))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.bottom, 12)
            }

            Divider()

            HStack {
                Spacer()
                Button(action: { focusVM.startFocus() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10))
                        Text("Start Focus")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(focusVM.selectedTask != nil && LLMProvider.isConfigured ? Color.calmTeal : Color.gray.opacity(0.4))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(focusVM.selectedTask == nil || !LLMProvider.isConfigured)
                Spacer()
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - Task Selector

    private var taskSelector: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(groupVM.topLevelGroups) { group in
                taskGroupSection(group: group, depth: 0)
            }
        }
    }

    @ViewBuilder
    private func taskGroupSection(group: TaskGroup, depth: Int) -> some View {
        let groupId = group.id ?? ""
        let tasksInGroup = taskVM.tasks.filter { $0.groupId == groupId && !$0.isComplete }
        let children = groupVM.childGroups(of: groupId)

        if !tasksInGroup.isEmpty || !children.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "folder")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.calmTeal)
                    Text(group.name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.6))
                }
                .padding(.leading, CGFloat(12 + depth * 12))
                .padding(.vertical, 4)

                ForEach(tasksInGroup) { task in
                    let isSelected = focusVM.selectedTask?.id == task.id
                    Button(action: { focusVM.selectedTask = task }) {
                        HStack(spacing: 6) {
                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 11))
                                .foregroundStyle(isSelected ? Color.calmTeal : .primary.opacity(0.3))
                            Text(task.name)
                                .font(.system(size: 11))
                                .foregroundStyle(.primary.opacity(0.8))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.leading, CGFloat(12 + depth * 12 + 14))
                        .padding(.vertical, 3)
                        .background(isSelected ? Color.calmTeal.opacity(0.08) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                ForEach(children) { child in
                    AnyView(taskGroupSection(group: child, depth: depth + 1))
                }
            }
        }
    }
}
