import SwiftUI

struct TasksTabView: View {
    @EnvironmentObject var taskVM: TaskViewModel
    @EnvironmentObject var groupVM: GroupViewModel
    @EnvironmentObject var taskGoVM: TaskGoViewModel
    @State private var showAddTask = false
    @State private var showAddGroup = false
    @State private var newGroupName = ""
    @State private var renamingGroupId: String?
    @State private var renameText = ""
    @State private var confirmDeleteGroup = false
    @State private var isSelectMode = false
    @State private var selectedTaskIds: Set<String> = []
    @State private var batchTimeText = "30"
    @State private var editingTaskId: String?
    @State private var isColorMode = false
    @State private var selectedColor: String = "blue"

    @State private var draggingTaskId: String?
    @State private var dragOffset: CGFloat = 0
    @State private var targetDropIndex: Int?
    @State private var dragStartIndex: Int?
    @State private var rowHeight: CGFloat = 55
    @State private var justDragged = false
    @State private var shiftHeld = false

    var body: some View {
        VStack(spacing: 0) {
            if groupVM.isAtRoot {
                rootBrowser
            } else {
                groupContentView
            }
        }
        .onChange(of: groupVM.selectedGroupId) { _, newGroupId in
            showAddTask = false
            isSelectMode = false
            selectedTaskIds.removeAll()
            if let groupId = newGroupId {
                if groupId == GroupViewModel.allGroupId {
                    taskVM.startListeningAll()
                } else {
                    taskVM.startListening(groupId: groupId)
                }
            } else {
                taskVM.stopListening()
            }
        }
        .onAppear {
            if let groupId = groupVM.selectedGroupId {
                if groupId == GroupViewModel.allGroupId {
                    taskVM.startListeningAll()
                } else {
                    taskVM.startListening(groupId: groupId)
                }
            }
            NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                shiftHeld = event.modifierFlags.contains(.shift)
                return event
            }
        }
    }

    // MARK: - Root Browser

    private var rootBrowser: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Task Groups")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: { showAddGroup.toggle() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if showAddGroup {
                addGroupInline
                Divider()
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(groupVM.topLevelGroups) { group in
                        groupRow(group)
                        Divider().padding(.leading, 36)
                    }

                    if groupVM.topLevelGroups.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 24))
                                .foregroundStyle(.primary.opacity(0.15))
                            Text("No groups yet")
                                .font(.system(size: 11))
                                .foregroundStyle(.primary.opacity(0.35))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                }
            }

            Divider()

            Button(action: { groupVM.selectAllGroup() }) {
                HStack(spacing: 8) {
                    Image(systemName: "tray.full")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.calmTeal)
                    Text("All Tasks")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.25))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func groupRow(_ group: TaskGroup) -> some View {
        let subCount = groupVM.groups.filter { $0.parentId == group.id }.count

        return Button(action: { groupVM.pushGroup(group) }) {
            HStack(spacing: 8) {
                Image(systemName: subCount > 0 ? "folder.fill" : "folder")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.calmTeal)
                    .frame(width: 16)

                Text(group.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineLimit(1)

                if subCount > 0 {
                    Text("\(subCount)")
                        .font(.system(size: 9))
                        .foregroundStyle(.primary.opacity(0.3))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.25))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Group Content View (inside a group or All Tasks)

    private var groupContentView: some View {
        VStack(spacing: 0) {
            groupHeader

            Divider()

            if showAddGroup {
                addGroupInline
                Divider()
            }

            if groupVM.isInsideGroup {
                let children = groupVM.childGroups
                if !children.isEmpty || showAddGroup {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(children) { group in
                                groupRow(group)
                                Divider().padding(.leading, 36)
                            }
                        }
                    }
                    .frame(maxHeight: min(CGFloat(children.count) * 40, 160))

                    Divider()
                }
            }

            if showAddTask {
                AddTaskView(groupId: groupVM.selectedGroupId ?? "", onDismiss: {
                    showAddTask = false
                })
            } else if groupVM.isInsideGroup && taskVM.tasks.isEmpty && groupVM.childGroups.isEmpty {
                emptyGroupState
            } else if groupVM.isAllGroupSelected && taskVM.tasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
    }

    private var groupHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button(action: {
                    if groupVM.isAllGroupSelected {
                        groupVM.popToRoot()
                    } else {
                        groupVM.popGroup()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Color.calmTeal)
                }
                .buttonStyle(.plain)

                Spacer()

                if groupVM.isAllGroupSelected {
                    Text("All Tasks")
                        .font(.system(size: 13, weight: .semibold))
                } else if let group = groupVM.currentGroup {
                    if renamingGroupId == group.id {
                        renameGroupInline(group: group)
                    } else {
                        Text(group.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if groupVM.isInsideGroup {
                    Button(action: { showAddGroup.toggle() }) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 10))
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Add sub-group")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if let group = groupVM.currentGroup, !group.isDefault, renamingGroupId != group.id {
                HStack(spacing: 12) {
                    Button(action: {
                        renameText = group.name
                        renamingGroupId = group.id
                    }) {
                        Text("Rename")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.calmTeal)
                    }
                    .buttonStyle(.plain)

                    if confirmDeleteGroup {
                        Text("Delete group & contents?")
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                        Button(action: {
                            let g = group
                            Task { await groupVM.deleteGroup(g) }
                            confirmDeleteGroup = false
                        }) {
                            Text("Yes")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        Button(action: { confirmDeleteGroup = false }) {
                            Text("No")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: { confirmDeleteGroup = true }) {
                            Text("Delete")
                                .font(.system(size: 10))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.05))
            }
        }
    }

    // MARK: - Inline Add/Rename Group

    private var addGroupInline: some View {
        HStack(spacing: 8) {
            TextField(groupVM.isInsideGroup ? "Sub-group name" : "Group name", text: $newGroupName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity)
                .onSubmit { createGroup() }

            Button("Add") { createGroup() }
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
        let parentId = groupVM.currentGroupId
        Task {
            await groupVM.addGroup(name: newGroupName, parentId: parentId)
            newGroupName = ""
            showAddGroup = false
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No tasks yet")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.5))
            Button("Add Task") { showAddTask = true }
                .buttonStyle(.borderedProminent)
                .tint(Color.calmTeal)
                .controlSize(.small)
            Spacer()
        }
    }

    private var emptyGroupState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("This group is empty")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.5))
            HStack(spacing: 12) {
                Button("Add Task") { showAddTask = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.calmTeal)
                    .controlSize(.small)
                Button("Add Sub-group") {
                    showAddGroup = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Spacer()
        }
    }

    // MARK: - Task List (preserved from original)

    private var taskList: some View {
        VStack(spacing: 0) {
            if isSelectMode && !selectedTaskIds.isEmpty {
                let resolvedTaskIds = resolveSelectedToTaskIds()
                let hasGrouped = selectedTaskIds.contains(where: { id in
                    taskVM.tasks.contains { $0.batchId == id || $0.chainId == id }
                })
                let allUngrouped = !hasGrouped

                HStack(spacing: 5) {
                    Text("\(selectedTaskIds.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.calmTeal)

                    if taskGoVM.isActive {
                        Button {
                            taskGoVM.addLane(taskIds: Set(resolvedTaskIds))
                            isSelectMode = false
                            selectedTaskIds.removeAll()
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "plus.square.on.square").font(.system(size: 8))
                                Text("Add Lane").font(.system(size: 10, weight: .bold))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.mini)
                    } else {
                        Button {
                            taskGoVM.startTaskGoWithSelected(Set(resolvedTaskIds))
                            isSelectMode = false
                            selectedTaskIds.removeAll()
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.fill").font(.system(size: 8))
                                Text("Task Go!").font(.system(size: 10, weight: .bold))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.calmTeal)
                        .controlSize(.mini)
                    }

                    Spacer()

                    if hasGrouped {
                        Button("Ungroup") {
                            Task {
                                for id in selectedTaskIds {
                                    let batchTasks = taskVM.tasksInBatch(id)
                                    for t in batchTasks { await taskVM.unbatchTask(t) }
                                    let chainTasks = taskVM.tasksInChain(id)
                                    for t in chainTasks { await taskVM.unchainTask(t) }
                                }
                                isSelectMode = false
                                selectedTaskIds.removeAll()
                            }
                        }
                        .font(.system(size: 9))
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }

                    if allUngrouped && selectedTaskIds.count >= 2 {
                        TextField("min", text: $batchTimeText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 30)
                            .font(.system(size: 9))
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
                        .font(.system(size: 9))
                        .buttonStyle(.bordered)
                        .controlSize(.mini)

                        Button("Chain") {
                            let ids = Array(selectedTaskIds)
                            Task {
                                await taskVM.chainTasks(ids)
                                isSelectMode = false
                                selectedTaskIds.removeAll()
                            }
                        }
                        .font(.system(size: 9))
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.06))

                Divider()
            }

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

                    Button(action: { selectedColor = "none" }) {
                        ZStack {
                            Circle()
                                .fill(Color(.windowBackgroundColor))
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1))
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

                    Button(action: { isColorMode = false }) {
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

                            if isSelectMode {
                                let selectId = task.batchId ?? task.chainId ?? task.id ?? ""
                                let isSelected = selectedTaskIds.contains(selectId)
                                Button(action: {
                                    if isSelected {
                                        selectedTaskIds.remove(selectId)
                                    } else {
                                        selectedTaskIds.insert(selectId)
                                    }
                                }) {
                                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 14))
                                        .foregroundStyle(isSelected ? Color.calmTeal : .primary.opacity(0.3))
                                }
                                .buttonStyle(.plain)
                            }

                            TaskRowView(task: task, editingTaskId: $editingTaskId, displayIndex: index + 1, dragLocked: justDragged)
                        }
                        .overlay {
                            if shiftHeld {
                                let selectId = task.batchId ?? task.chainId ?? task.id ?? ""
                                let isShiftSelected = selectedTaskIds.contains(selectId)
                                Color.calmTeal.opacity(isShiftSelected ? 0.12 : 0.001)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if isShiftSelected {
                                            selectedTaskIds.remove(selectId)
                                            if selectedTaskIds.isEmpty { isSelectMode = false }
                                        } else {
                                            selectedTaskIds.insert(selectId)
                                            isSelectMode = true
                                        }
                                    }
                            }
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
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 8)
                                .onChanged { value in
                                    guard !groupVM.isAllGroupSelected else { return }
                                    justDragged = true
                                    if draggingTaskId == nil {
                                        draggingTaskId = task.id
                                        dragStartIndex = index
                                    }
                                    guard draggingTaskId == task.id else { return }
                                    dragOffset = value.translation.height
                                    let rowsMoved = Int(round(dragOffset / max(rowHeight, 40)))
                                    let items = taskVM.incompleteTasksForDisplay
                                    let newIdx = min(max(index + rowsMoved, 0), items.count - 1)
                                    targetDropIndex = newIdx
                                }
                                .onEnded { _ in
                                    guard !groupVM.isAllGroupSelected else { return }
                                    if let startIdx = dragStartIndex,
                                       let targetIdx = targetDropIndex,
                                       startIdx != targetIdx {
                                        let s = startIdx
                                        let t = targetIdx
                                        Task {
                                            await taskVM.moveTask(from: IndexSet(integer: s), to: t > s ? t + 1 : t)
                                        }
                                    }
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        draggingTaskId = nil
                                        dragOffset = 0
                                        targetDropIndex = nil
                                        dragStartIndex = nil
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        justDragged = false
                                    }
                                }
                        )

                        Divider().padding(.leading, 10)
                    }

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

            HStack {
                if groupVM.isInsideGroup || groupVM.isAllGroupSelected {
                    Button(action: {
                        if groupVM.isAllGroupSelected, let firstGroup = groupVM.groups.first {
                            groupVM.selectGroup(firstGroup)
                        }
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
                }

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
                        Button(action: { isSelectMode = true }) {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle").font(.system(size: 9))
                                Text("Select").font(.system(size: 10))
                            }
                            .foregroundStyle(.primary.opacity(0.5))
                        }
                        .buttonStyle(.plain)

                        Button(action: { isColorMode.toggle() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "paintpalette").font(.system(size: 9))
                                Text("Color").font(.system(size: 10))
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

    private func resolveSelectedToTaskIds() -> [String] {
        var taskIds: [String] = []
        for id in selectedTaskIds {
            let batchTasks = taskVM.tasksInBatch(id)
            if !batchTasks.isEmpty {
                taskIds.append(contentsOf: batchTasks.compactMap { $0.id })
                continue
            }
            let chainTasks = taskVM.tasksInChain(id)
            if !chainTasks.isEmpty {
                taskIds.append(contentsOf: chainTasks.compactMap { $0.id })
                continue
            }
            taskIds.append(id)
        }
        return taskIds
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
