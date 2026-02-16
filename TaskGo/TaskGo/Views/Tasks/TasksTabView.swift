import SwiftUI

struct TasksTabView: View {
    @EnvironmentObject var taskVM: TaskViewModel
    @EnvironmentObject var groupVM: GroupViewModel
    @State private var showAddTask = false
    @State private var showAddGroup = false
    @State private var newGroupName = ""

    var body: some View {
        VStack(spacing: 0) {
            // Group tabs
            groupTabBar

            Divider()

            // Task list
            if taskVM.tasks.isEmpty {
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
        .sheet(isPresented: $showAddTask) {
            AddTaskView(groupId: groupVM.selectedGroupId ?? "")
        }
    }

    private var groupTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(groupVM.groups) { group in
                    GroupTabButton(
                        group: group,
                        isSelected: group.id == groupVM.selectedGroupId,
                        onSelect: { groupVM.selectGroup(group) },
                        onRename: { newName in
                            Task { await groupVM.renameGroup(group, to: newName) }
                        },
                        onDelete: group.isDefault ? nil : { [group] in
                            let groupToDelete = group
                            Task { await groupVM.deleteGroup(groupToDelete) }
                        }
                    )
                }

                // Add group button
                Button(action: {
                    showAddGroup = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAddGroup) {
                    VStack(spacing: 8) {
                        Text("New Group")
                            .font(.headline)
                        TextField("Group name", text: $newGroupName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                        HStack {
                            Button("Cancel") {
                                showAddGroup = false
                                newGroupName = ""
                            }
                            Button("Create") {
                                Task {
                                    await groupVM.addGroup(name: newGroupName)
                                    newGroupName = ""
                                    showAddGroup = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.calmTeal)
                            .disabled(newGroupName.isEmpty)
                        }
                    }
                    .padding()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
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
            // Incomplete tasks
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(taskVM.incompleteTasks) { task in
                        TaskRowView(task: task)
                        Divider()
                            .padding(.leading, 36)
                    }

                    // Completed section
                    if !taskVM.completedTasks.isEmpty {
                        HStack {
                            Text("Completed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))

                        ForEach(taskVM.completedTasks) { task in
                            TaskRowView(task: task)
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
            }

            Divider()

            // Add task button at bottom
            Button(action: {
                showAddTask = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.calmTeal)
                    Text("Add task")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }
}

struct GroupTabButton: View {
    let group: TaskGroup
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: (String) -> Void
    let onDelete: (() -> Void)?

    @State private var isEditing = false
    @State private var editName = ""

    var body: some View {
        Button(action: onSelect) {
            Text(group.name)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.calmTeal : .primary.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.calmTeal.opacity(0.12) : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename") {
                editName = group.name
                isEditing = true
            }
            if let onDelete = onDelete {
                Divider()
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            }
        }
        .popover(isPresented: $isEditing) {
            VStack(spacing: 8) {
                Text("Rename Group")
                    .font(.headline)
                TextField("Group name", text: $editName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                HStack {
                    Button("Cancel") { isEditing = false }
                    Button("Save") {
                        onRename(editName)
                        isEditing = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.calmTeal)
                    .disabled(editName.isEmpty)
                }
            }
            .padding()
        }
    }
}
