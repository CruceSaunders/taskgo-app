import SwiftUI

struct TasksTabView: View {
    @EnvironmentObject var taskVM: TaskViewModel
    @EnvironmentObject var groupVM: GroupViewModel
    @EnvironmentObject var taskGoVM: TaskGoViewModel
    @State private var showAddTask = false
    @State private var addingTaskToGroupId: String?
    @State private var showAddGroup = false
    @State private var addingSubGroupToId: String?
    @State private var newGroupName = ""
    @State private var renamingGroupId: String?
    @State private var renameText = ""
    @State private var confirmDeleteGroupId: String?
    @State private var isSelectMode = false
    @State private var selectedTaskIds: Set<String> = []
    @State private var batchTimeText = "30"
    @State private var editingTaskId: String?
    @State private var isColorMode = false
    @State private var selectedColor: String = "blue"
    @State private var showAllCompleted = false

    @State private var draggingTaskId: String?
    @State private var dragOffset: CGFloat = 0
    @State private var targetDropIndex: Int?
    @State private var dragStartIndex: Int?
    @State private var rowHeight: CGFloat = 55
    @State private var justDragged = false
    @State private var shiftHeld = false

    @State private var draggingGroupId: String?
    @State private var groupDragOffset: CGFloat = 0
    @State private var dropTargetGroupId: String?
    @State private var groupDragStartIndex: Int?
    @State private var groupTargetIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            if groupVM.showingAllTasks {
                allTasksView
            } else {
                groupBrowser
            }

            if let errorMessage = groupVM.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                    Spacer()
                    Button(action: { groupVM.errorMessage = nil }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.08))
            }
        }
        .onChange(of: groupVM.showingAllTasks) { _, showing in
            if showing {
                taskVM.startListeningAll()
            }
        }
        .onChange(of: groupVM.expandedGroupIds) { _, _ in
            updateTaskListener()
        }
        .onAppear {
            updateTaskListener()
            NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                shiftHeld = event.modifierFlags.contains(.shift)
                return event
            }
        }
    }

    private func updateTaskListener() {
        if groupVM.showingAllTasks {
            taskVM.startListeningAll()
        } else if groupVM.hasExpandedGroups {
            taskVM.startListeningAll()
        } else {
            taskVM.stopListening()
        }
    }

    // MARK: - Group Browser (inline expand/collapse)

    private var groupBrowser: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Task Groups")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: {
                    addingSubGroupToId = nil
                    showAddGroup.toggle()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if showAddGroup && addingSubGroupToId == nil {
                addGroupInline(parentId: nil)
                Divider()
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    let topGroups = groupVM.topLevelGroups
                    ForEach(Array(topGroups.enumerated()), id: \.element.id) { index, group in
                        recursiveGroupRow(group: group, depth: 0, siblingIndex: index, siblingCount: topGroups.count)
                    }

                    if groupVM.topLevelGroups.isEmpty && !showAddGroup {
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

            Button(action: {
                groupVM.collapseAll()
                groupVM.selectAllGroup()
            }) {
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

    // MARK: - Recursive Group Row

    @ViewBuilder
    private func recursiveGroupRow(group: TaskGroup, depth: Int, siblingIndex: Int, siblingCount: Int) -> some View {
        let groupId = group.id ?? ""
        let isExpanded = groupVM.isExpanded(groupId)
        let children = groupVM.childGroups(of: groupId)
        let isDragging = draggingGroupId == groupId

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { groupVM.toggleGroup(groupId) } }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.calmTeal)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                Image(systemName: children.isEmpty ? "folder" : "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.calmTeal)
                    .frame(width: 16)

                if renamingGroupId == groupId {
                    renameField(group: group)
                } else {
                    Text(group.name)
                        .font(.system(size: 12, weight: isExpanded ? .semibold : .regular))
                        .foregroundStyle(.primary.opacity(0.8))
                        .lineLimit(1)
                }

                Spacer()

                if !group.isDefault && renamingGroupId != groupId {
                    groupActions(group: group)
                }
            }
            .padding(.leading, CGFloat(12 + depth * 16))
            .padding(.trailing, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .opacity(isDragging ? 0.5 : 1.0)
            .offset(y: isDragging ? groupDragOffset : 0)
            .zIndex(isDragging ? 100 : 0)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        if draggingGroupId == nil {
                            draggingGroupId = groupId
                            groupDragStartIndex = siblingIndex
                        }
                        guard draggingGroupId == groupId else { return }
                        groupDragOffset = value.translation.height
                        let rowH: CGFloat = 40
                        let rowsMoved = Int(round(groupDragOffset / rowH))
                        let newIdx = min(max(siblingIndex + rowsMoved, 0), siblingCount - 1)
                        groupTargetIndex = newIdx
                    }
                    .onEnded { _ in
                        guard draggingGroupId == groupId else { return }
                        if let startIdx = groupDragStartIndex,
                           let targetIdx = groupTargetIndex,
                           startIdx != targetIdx {
                            let parentId = group.parentId
                            Task {
                                await groupVM.reorderGroup(
                                    from: IndexSet(integer: startIdx),
                                    to: targetIdx > startIdx ? targetIdx + 1 : targetIdx,
                                    parentId: parentId
                                )
                            }
                        }
                        withAnimation(.easeOut(duration: 0.15)) {
                            draggingGroupId = nil
                            groupDragOffset = 0
                            groupDragStartIndex = nil
                            groupTargetIndex = nil
                        }
                    }
            )

            Divider().padding(.leading, CGFloat(12 + depth * 16 + 34))

            if isExpanded {
                let tasksForGroup = taskVM.tasks.filter { $0.groupId == groupId }
                let incomplete = tasksForGroup.filter { !$0.isComplete }.sorted { $0.position < $1.position }
                let completed = tasksForGroup.filter { $0.isComplete && !($0.recurrence != nil) }
                    .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }

                ForEach(Array(incomplete.enumerated()), id: \.element.id) { index, task in
                    let isTaskDragging = draggingTaskId == task.id

                    TaskRowView(task: task, editingTaskId: $editingTaskId, displayIndex: index + 1, dragLocked: justDragged)
                        .padding(.leading, CGFloat(depth * 16 + 16))
                        .offset(y: isTaskDragging ? dragOffset : 0)
                        .zIndex(isTaskDragging ? 100 : 0)
                        .opacity(isTaskDragging ? 0.85 : 1.0)
                        .background(isTaskDragging ? Color(.windowBackgroundColor) : Color.clear)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 8)
                                .onChanged { value in
                                    justDragged = true
                                    if draggingTaskId == nil {
                                        draggingTaskId = task.id
                                        dragStartIndex = index
                                    }
                                    guard draggingTaskId == task.id else { return }
                                    dragOffset = value.translation.height
                                    let rowsMoved = Int(round(dragOffset / max(rowHeight, 40)))
                                    let newIdx = min(max(index + rowsMoved, 0), incomplete.count - 1)
                                    targetDropIndex = newIdx
                                }
                                .onEnded { _ in
                                    if let startIdx = dragStartIndex,
                                       let targetIdx = targetDropIndex,
                                       startIdx != targetIdx {
                                        let gid = groupId
                                        Task {
                                            await taskVM.moveTaskInGroup(from: IndexSet(integer: startIdx), to: targetIdx > startIdx ? targetIdx + 1 : targetIdx, groupId: gid)
                                        }
                                    }
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        draggingTaskId = nil
                                        dragOffset = 0
                                        targetDropIndex = nil
                                        dragStartIndex = nil
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { justDragged = false }
                                }
                        )

                    Divider().padding(.leading, CGFloat(12 + depth * 16 + 34))
                }

                if addingTaskToGroupId == groupId {
                    AddTaskView(groupId: groupId, onDismiss: { addingTaskToGroupId = nil })
                        .padding(.leading, CGFloat(depth * 16 + 16))
                } else {
                    Button(action: { addingTaskToGroupId = groupId }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.calmTeal.opacity(0.6))
                            Text("Add task")
                                .font(.system(size: 10))
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                        .padding(.leading, CGFloat(12 + depth * 16 + 34))
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, CGFloat(12 + depth * 16 + 34))
                }

                if !completed.isEmpty {
                    let visibleCompleted = showAllCompleted ? completed : Array(completed.prefix(3))

                    HStack {
                        Text("Completed")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.35))
                        Spacer()
                    }
                    .padding(.leading, CGFloat(12 + depth * 16 + 34))
                    .padding(.trailing, 12)
                    .padding(.vertical, 3)

                    ForEach(visibleCompleted) { task in
                        TaskRowView(task: task, editingTaskId: $editingTaskId)
                            .padding(.leading, CGFloat(depth * 16 + 16))
                        Divider().padding(.leading, CGFloat(12 + depth * 16 + 34))
                    }

                    if completed.count > 3 {
                        Button(action: { showAllCompleted.toggle() }) {
                            Text(showAllCompleted ? "See less" : "See more (\(completed.count - 3))")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.calmTeal)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, CGFloat(12 + depth * 16 + 34))
                        .padding(.vertical, 3)
                    }
                }

                ForEach(Array(children.enumerated()), id: \.element.id) { childIndex, child in
                    AnyView(recursiveGroupRow(group: child, depth: depth + 1, siblingIndex: childIndex, siblingCount: children.count))
                }

                if addingSubGroupToId == groupId {
                    addGroupInline(parentId: groupId)
                        .padding(.leading, CGFloat(depth * 16 + 16))
                } else {
                    Button(action: { addingSubGroupToId = groupId }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.calmTeal.opacity(0.6))
                            Text("Add sub-group")
                                .font(.system(size: 10))
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                        .padding(.leading, CGFloat(12 + depth * 16 + 34))
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Divider().padding(.leading, CGFloat(12 + depth * 16))
            }
        }
    }

    // MARK: - Group Actions (rename/delete, hover-only)

    @ViewBuilder
    private func groupActions(group: TaskGroup) -> some View {
        let groupId = group.id ?? ""

        if confirmDeleteGroupId == groupId {
            HStack(spacing: 4) {
                Button(action: {
                    Task { await groupVM.deleteGroup(group) }
                    confirmDeleteGroupId = nil
                }) {
                    Text("Delete")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
                Button(action: { confirmDeleteGroupId = nil }) {
                    Text("Cancel")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        } else {
            HStack(spacing: 6) {
                Button(action: {
                    renameText = group.name
                    renamingGroupId = groupId
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 8))
                        .foregroundStyle(.primary.opacity(0.3))
                }
                .buttonStyle(.plain)

                Button(action: { confirmDeleteGroupId = groupId }) {
                    Image(systemName: "trash")
                        .font(.system(size: 8))
                        .foregroundStyle(.red.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Inline Add/Rename

    private func addGroupInline(parentId: String?) -> some View {
        HStack(spacing: 8) {
            TextField(parentId != nil ? "Sub-group name" : "Group name", text: $newGroupName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity)
                .onSubmit { createGroup(parentId: parentId) }

            Button("Add") { createGroup(parentId: parentId) }
                .buttonStyle(.borderedProminent)
                .tint(Color.calmTeal)
                .controlSize(.small)
                .disabled(newGroupName.isEmpty)

            Button(action: {
                showAddGroup = false
                addingSubGroupToId = nil
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

    @ViewBuilder
    private func renameField(group: TaskGroup) -> some View {
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
    }

    private func createGroup(parentId: String?) {
        guard !newGroupName.isEmpty else { return }
        Task {
            await groupVM.addGroup(name: newGroupName, parentId: parentId)
            newGroupName = ""
            showAddGroup = false
            addingSubGroupToId = nil
        }
    }

    // MARK: - All Tasks View

    private var allTasksView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button(action: { groupVM.deselectAllGroup() }) {
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

                Text("All Tasks")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()
                Spacer().frame(width: 40)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if taskVM.tasks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checklist")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No tasks yet")
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.5))
                    Spacer()
                }
            } else {
                taskListAll
            }
        }
    }

    // MARK: - All Tasks List

    private var taskListAll: some View {
        VStack(spacing: 0) {
            if isSelectMode && !selectedTaskIds.isEmpty {
                selectActionBar
                Divider()
            }

            if isColorMode {
                colorBar
                Divider()
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(taskVM.incompleteTasksForDisplay.enumerated()), id: \.element.id) { index, task in
                        allTaskRow(task: task, index: index)
                        Divider().padding(.leading, 10)
                    }

                    let completed = taskVM.completedTasksForDisplay
                    if !completed.isEmpty {
                        HStack {
                            Text("Completed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.08))

                        let visibleCompleted = showAllCompleted ? completed : Array(completed.prefix(3))
                        ForEach(visibleCompleted) { task in
                            TaskRowView(task: task, editingTaskId: $editingTaskId)
                            Divider().padding(.leading, 20)
                        }

                        if completed.count > 3 {
                            Button(action: { showAllCompleted.toggle() }) {
                                Text(showAllCompleted ? "See less" : "See more (\(completed.count - 3))")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.calmTeal)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                if !taskVM.incompleteTasksForDisplay.isEmpty {
                    if isSelectMode {
                        Button(action: { isSelectMode = false; selectedTaskIds.removeAll() }) {
                            Text("Cancel").font(.system(size: 10)).foregroundStyle(.red)
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

    @ViewBuilder
    private func allTaskRow(task: TaskItem, index: Int) -> some View {
        let isDragging = draggingTaskId == task.id

        HStack(spacing: 6) {
            if isColorMode {
                Button(action: {
                    if let id = task.id {
                        Task { await taskVM.setColorTag([id], color: selectedColor == "none" ? nil : selectedColor) }
                    }
                }) {
                    if selectedColor == "none" {
                        Image(systemName: "minus.circle").font(.system(size: 12)).foregroundStyle(.red.opacity(0.5))
                    } else {
                        Circle().fill(colorFromName(selectedColor)).frame(width: 12, height: 12)
                    }
                }
                .buttonStyle(.plain)
            }

            if isSelectMode {
                let selectId = task.batchId ?? task.chainId ?? task.id ?? ""
                let isSelected = selectedTaskIds.contains(selectId)
                Button(action: {
                    if isSelected { selectedTaskIds.remove(selectId) } else { selectedTaskIds.insert(selectId) }
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
        .offset(y: isDragging ? dragOffset : 0)
        .zIndex(isDragging ? 100 : 0)
        .opacity(isDragging ? 0.85 : 1.0)
    }

    // MARK: - Select/Color Bars

    private var selectActionBar: some View {
        let resolvedTaskIds = resolveSelectedToTaskIds()
        let hasGrouped = selectedTaskIds.contains(where: { id in
            taskVM.tasks.contains { $0.batchId == id || $0.chainId == id }
        })
        let allUngrouped = !hasGrouped

        return HStack(spacing: 5) {
            Text("\(selectedTaskIds.count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.calmTeal)

            if taskGoVM.isActive {
                Button {
                    taskGoVM.addLane(taskIds: Set(resolvedTaskIds))
                    isSelectMode = false; selectedTaskIds.removeAll()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "plus.square.on.square").font(.system(size: 8))
                        Text("Add Lane").font(.system(size: 10, weight: .bold))
                    }
                }
                .buttonStyle(.borderedProminent).tint(.orange).controlSize(.mini)
            } else {
                Button {
                    taskGoVM.startTaskGoWithSelected(Set(resolvedTaskIds))
                    isSelectMode = false; selectedTaskIds.removeAll()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill").font(.system(size: 8))
                        Text("Task Go!").font(.system(size: 10, weight: .bold))
                    }
                }
                .buttonStyle(.borderedProminent).tint(Color.calmTeal).controlSize(.mini)
            }

            Spacer()

            if hasGrouped {
                Button("Ungroup") {
                    Task {
                        for id in selectedTaskIds {
                            for t in taskVM.tasksInBatch(id) { await taskVM.unbatchTask(t) }
                            for t in taskVM.tasksInChain(id) { await taskVM.unchainTask(t) }
                        }
                        isSelectMode = false; selectedTaskIds.removeAll()
                    }
                }
                .font(.system(size: 9)).buttonStyle(.bordered).controlSize(.mini)
            }

            if allUngrouped && selectedTaskIds.count >= 2 {
                TextField("min", text: $batchTimeText)
                    .textFieldStyle(.roundedBorder).frame(width: 30).font(.system(size: 9)).multilineTextAlignment(.center)

                Button("Batch") {
                    let ids = Array(selectedTaskIds); let time = (Int(batchTimeText) ?? 30) * 60
                    Task { await taskVM.batchTasks(ids, batchTimeEstimate: time); isSelectMode = false; selectedTaskIds.removeAll() }
                }
                .font(.system(size: 9)).buttonStyle(.bordered).controlSize(.mini)

                Button("Chain") {
                    let ids = Array(selectedTaskIds)
                    Task { await taskVM.chainTasks(ids); isSelectMode = false; selectedTaskIds.removeAll() }
                }
                .font(.system(size: 9)).buttonStyle(.bordered).controlSize(.mini)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.06))
    }

    private var colorBar: some View {
        HStack(spacing: 6) {
            Text("Tap tasks to color:")
                .font(.system(size: 9))
                .foregroundStyle(.primary.opacity(0.5))

            ForEach(["red", "blue", "green", "yellow", "purple", "orange", "pink", "teal"], id: \.self) { color in
                Button(action: { selectedColor = color }) {
                    Circle().fill(colorFromName(color)).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0).frame(width: 17, height: 17))
                }
                .buttonStyle(.plain)
            }

            Button(action: { selectedColor = "none" }) {
                ZStack {
                    Circle().fill(Color(.windowBackgroundColor)).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1))
                    Rectangle().fill(Color.red).frame(width: 12, height: 1.5).rotationEffect(.degrees(-45))
                }
                .overlay(Circle().stroke(Color.primary, lineWidth: selectedColor == "none" ? 2 : 0).frame(width: 17, height: 17))
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: { isColorMode = false }) {
                Image(systemName: "xmark").font(.system(size: 9)).foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.06))
    }

    // MARK: - Helpers

    private func resolveSelectedToTaskIds() -> [String] {
        var taskIds: [String] = []
        for id in selectedTaskIds {
            let batchTasks = taskVM.tasksInBatch(id)
            if !batchTasks.isEmpty { taskIds.append(contentsOf: batchTasks.compactMap { $0.id }); continue }
            let chainTasks = taskVM.tasksInChain(id)
            if !chainTasks.isEmpty { taskIds.append(contentsOf: chainTasks.compactMap { $0.id }); continue }
            taskIds.append(id)
        }
        return taskIds
    }
}

// MARK: - Color Helper

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
