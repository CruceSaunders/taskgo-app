import SwiftUI

struct TasksTabView: View {
    @EnvironmentObject var taskVM: TaskViewModel
    @EnvironmentObject var groupVM: GroupViewModel
    @State private var showAddTask = false
    @State private var showAddGroup = false
    @State private var newGroupName = ""
    @State private var renamingGroupId: String?
    @State private var renameText = ""
    @State private var isSelectMode = false
    @State private var selectedTaskIds: Set<String> = []
    @State private var batchTimeText = "30"
    @State private var editingTaskId: String?
    @State private var isColorMode = false
    @State private var selectedColor: String = "blue"

    // Custom drag reorder state (no NSDraggingSession = panel stays open)
    @State private var draggingTaskId: String?
    @State private var dragOffset: CGFloat = 0
    @State private var targetDropIndex: Int?
    @State private var dragStartIndex: Int?
    @State private var rowHeight: CGFloat = 55

    var body: some View {
        VStack(spacing: 0) {
            groupTabBar

            Divider()

            if showAddGroup {
                addGroupInline
                Divider()
            }

            if showAddTask {
                AddTaskView(groupId: groupVM.selectedGroupId ?? "", onDismiss: {
                    showAddTask = false
                })
            } else if taskVM.tasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .onChange(of: groupVM.selectedGroupId) { _, newGroupId in
            if let groupId = newGroupId {
                taskVM.startListening(groupId: groupId)
            }
        }
        .onAppear {
            if let groupId = groupVM.selectedGroupId {
                taskVM.startListening(groupId: groupId)
            }
        }
    }

    private var groupTabBar: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(groupVM.groups) { group in
                        Button(action: { groupVM.selectGroup(group) }) {
                            Text(group.name)
                                .font(.system(size: 11, weight: group.id == groupVM.selectedGroupId ? .semibold : .regular))
                                .foregroundStyle(group.id == groupVM.selectedGroupId ? Color.calmTeal : .primary.opacity(0.6))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(group.id == groupVM.selectedGroupId ? Color.calmTeal.opacity(0.12) : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: {
                        showAddGroup.toggle()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }

            // Inline actions for selected non-default group
            if let selectedGroup = groupVM.selectedGroup, !selectedGroup.isDefault {
                if renamingGroupId == selectedGroup.id {
                    renameGroupInline(group: selectedGroup)
                } else {
                    HStack(spacing: 12) {
                        Button(action: {
                            renameText = selectedGroup.name
                            renamingGroupId = selectedGroup.id
                        }) {
                            Text("Rename")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.calmTeal)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            let groupToDelete = selectedGroup
                            Task { await groupVM.deleteGroup(groupToDelete) }
                        }) {
                            Text("Delete group")
                                .font(.system(size: 10))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.05))
                }
            }
        }
    }

    private var addGroupInline: some View {
        HStack(spacing: 8) {
            TextField("Group name", text: $newGroupName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity)
                .onSubmit {
                    createGroup()
                }

            Button("Add") {
                createGroup()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.calmTeal)
            .controlSize(.small)
            .disabled(newGroupName.isEmpty)

            Button(action: {
                showAddGroup = false
                newGroupName = ""
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func renameGroupInline(group: TaskGroup) -> some View {
        HStack(spacing: 4) {
            TextField("Name", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
                .frame(width: 100)
                .onSubmit {
                    Task { await groupVM.renameGroup(group, to: renameText) }
                    renamingGroupId = nil
                }

            Button(action: {
                Task { await groupVM.renameGroup(group, to: renameText) }
                renamingGroupId = nil
            }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.calmTeal)
            }
            .buttonStyle(.plain)

            Button(action: { renamingGroupId = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    private func createGroup() {
        guard !newGroupName.isEmpty else { return }
        Task {
            await groupVM.addGroup(name: newGroupName)
            newGroupName = ""
            showAddGroup = false
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No tasks yet")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.5))
            Button("Add Task") {
                showAddTask = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.calmTeal)
            .controlSize(.small)
            Spacer()
        }
    }

    private var taskList: some View {
        VStack(spacing: 0) {
            // Action bar (when selecting 2+)
            if isSelectMode && selectedTaskIds.count >= 2 {
                HStack(spacing: 6) {
                    Text("\(selectedTaskIds.count) selected")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.6))

                    Spacer()

                    TextField("min", text: $batchTimeText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 36)
                        .font(.system(size: 10))
                        .multilineTextAlignment(.center)

                    Button("Batch") {
                        let ids = Array(selectedTaskIds)
                        let time = (Int(batchTimeText) ?? 30) * 60
                        Task {
                            await taskVM.batchTasks(ids, batchTimeEstimate: time)
                            isSelectMode = false
                            selectedTaskIds.removeAll()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.calmTeal)
                    .controlSize(.mini)

                    Button("Chain") {
                        let ids = Array(selectedTaskIds)
                        Task {
                            await taskVM.chainTasks(ids)
                            isSelectMode = false
                            selectedTaskIds.removeAll()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.06))

                Divider()
            }

            // Color mode bar
            if isColorMode {
                HStack(spacing: 6) {
                    Text("Tap tasks to color:")
                        .font(.system(size: 9))
                        .foregroundStyle(.primary.opacity(0.5))

                    ForEach(["red", "blue", "green", "yellow", "purple", "orange", "pink", "teal"], id: \.self) { color in
                        Button(action: { selectedColor = color }) {
                            Circle()
                                .fill(colorFromName(color))
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                        .frame(width: 17, height: 17)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    // Remove color
                    Button(action: { selectedColor = "none" }) {
                        ZStack {
                            Circle()
                                .fill(Color(.windowBackgroundColor))
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1)
                                )
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 12, height: 1.5)
                                .rotationEffect(.degrees(-45))
                        }
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: selectedColor == "none" ? 2 : 0)
                                .frame(width: 17, height: 17)
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: {
                        isColorMode = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.06))

                Divider()
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(taskVM.incompleteTasksForDisplay.enumerated()), id: \.element.id) { index, task in
                        let isDragging = draggingTaskId == task.id

                        HStack(spacing: 6) {
                            // Color mode
                            if isColorMode {
                                Button(action: {
                                    if let id = task.id {
                                        if selectedColor == "none" {
                                            Task { await taskVM.setColorTag([id], color: nil) }
                                        } else {
                                            Task { await taskVM.setColorTag([id], color: selectedColor) }
                                        }
                                    }
                                }) {
                                    if selectedColor == "none" {
                                        Image(systemName: "minus.circle")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.red.opacity(0.5))
                                    } else {
                                        Circle()
                                            .fill(colorFromName(selectedColor))
                                            .frame(width: 12, height: 12)
                                    }
                                }
                                .buttonStyle(.plain)
                            }

                            // Select mode
                            if isSelectMode, !task.isGrouped {
                                Button(action: {
                                    if let id = task.id {
                                        if selectedTaskIds.contains(id) {
                                            selectedTaskIds.remove(id)
                                        } else {
                                            selectedTaskIds.insert(id)
                                        }
                                    }
                                }) {
                                    Image(systemName: selectedTaskIds.contains(task.id ?? "") ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 14))
                                        .foregroundStyle(selectedTaskIds.contains(task.id ?? "") ? Color.calmTeal : .primary.opacity(0.3))
                                }
                                .buttonStyle(.plain)
                            }

                            TaskRowView(task: task, editingTaskId: $editingTaskId, displayIndex: index + 1)
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear.onAppear {
                                    if rowHeight != geo.size.height && geo.size.height > 10 {
                                        rowHeight = geo.size.height
                                    }
                                }
                            }
                        )
                        .offset(y: isDragging ? dragOffset : 0)
                        .zIndex(isDragging ? 100 : 0)
                        .opacity(isDragging ? 0.85 : 1.0)
                        .shadow(color: isDragging ? .black.opacity(0.15) : .clear, radius: isDragging ? 4 : 0, y: isDragging ? 2 : 0)
                        .background(isDragging ? Color(.windowBackgroundColor) : Color.clear)
                        .gesture(
                            LongPressGesture(minimumDuration: 0.2)
                                .sequenced(before: DragGesture())
                                .onChanged { value in
                                    switch value {
                                    case .second(true, let drag):
                                        if draggingTaskId == nil {
                                            draggingTaskId = task.id
                                            dragStartIndex = index
                                        }
                                        guard draggingTaskId == task.id, let drag = drag else { return }
                                        dragOffset = drag.translation.height

                                        // Track where we'd drop (visual only, no swap yet)
                                        let rowsMoved = Int(round(dragOffset / max(rowHeight, 40)))
                                        let items = taskVM.incompleteTasksForDisplay
                                        let newIdx = min(max(index + rowsMoved, 0), items.count - 1)
                                        targetDropIndex = newIdx
                                    default:
                                        break
                                    }
                                }
                                .onEnded { value in
                                    // Perform the swap on drop
                                    if let startIdx = dragStartIndex,
                                       let targetIdx = targetDropIndex,
                                       startIdx != targetIdx {
                                        Task {
                                            await taskVM.moveTask(
                                                from: IndexSet(integer: startIdx),
                                                to: targetIdx > startIdx ? targetIdx + 1 : targetIdx
                                            )
                                        }
                                    }
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        draggingTaskId = nil
                                        dragOffset = 0
                                        targetDropIndex = nil
                                        dragStartIndex = nil
                                    }
                                }
                        )

                        Divider().padding(.leading, 10)
                    }

                    // Completed section
                    if !taskVM.completedTasksForDisplay.isEmpty {
                        HStack {
                            Text("Completed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.08))

                        ForEach(taskVM.completedTasksForDisplay) { task in
                            TaskRowView(task: task, editingTaskId: $editingTaskId)
                            Divider().padding(.leading, 20)
                        }
                    }
                }
            }

            Divider()

            // Bottom bar: Add task + Select mode toggle
            HStack {
                Button(action: {
                    showAddTask = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.calmTeal)
                        Text("Add task")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if !taskVM.incompleteTasksForDisplay.isEmpty {
                    if isSelectMode {
                        Button(action: {
                            isSelectMode = false
                            selectedTaskIds.removeAll()
                        }) {
                            Text("Cancel")
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: {
                            isSelectMode = true
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "square.stack")
                                    .font(.system(size: 9))
                                Text("Batch")
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(Color.calmTeal)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            isSelectMode = true
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "link")
                                    .font(.system(size: 9))
                                Text("Chain")
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            isColorMode.toggle()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "paintpalette")
                                    .font(.system(size: 9))
                                Text("Color")
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(isColorMode ? .purple : .purple.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Helpers

private func colorFromName(_ name: String) -> Color {
    switch name {
    case "red": return .red
    case "blue": return .blue
    case "green": return .green
    case "yellow": return .yellow
    case "purple": return .purple
    case "orange": return .orange
    case "pink": return .pink
    case "teal": return .teal
    default: return .gray
    }
}
