import SwiftUI

struct TasksTabView: View {
    @EnvironmentObject var taskVM: TaskViewModel
    @EnvironmentObject var groupVM: GroupViewModel
    @State private var showAddTask = false
    @State private var showAddGroup = false
    @State private var newGroupName = ""
    @State private var renamingGroupId: String?
    @State private var renameText = ""

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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(groupVM.groups) { group in
                    if renamingGroupId == group.id {
                        renameGroupInline(group: group)
                    } else {
                        GroupTabButton(
                            group: group,
                            isSelected: group.id == groupVM.selectedGroupId,
                            onSelect: { groupVM.selectGroup(group) },
                            onRename: {
                                renameText = group.name
                                renamingGroupId = group.id
                            },
                            onDelete: group.isDefault ? nil : { [group] in
                                let groupToDelete = group
                                Task { await groupVM.deleteGroup(groupToDelete) }
                            }
                        )
                    }
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
            List {
                ForEach(taskVM.incompleteTasks) { task in
                    TaskRowView(task: task)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
                .onMove { source, destination in
                    Task { await taskVM.moveTask(from: source, to: destination) }
                }

                if !taskVM.completedTasks.isEmpty {
                    Section {
                        ForEach(taskVM.completedTasks) { task in
                            TaskRowView(task: task)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text("Completed")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Divider()

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
    let onRename: () -> Void
    let onDelete: (() -> Void)?

    @State private var showActions = false

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onSelect) {
                Text(group.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.calmTeal : .primary.opacity(0.6))
            }
            .buttonStyle(.plain)

            if isSelected && !group.isDefault {
                Button(action: { showActions.toggle() }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isSelected ? Color.calmTeal.opacity(0.12) : Color.clear)
        .clipShape(Capsule())
        .overlay(alignment: .bottom) {
            if showActions {
                HStack(spacing: 8) {
                    Button(action: {
                        showActions = false
                        onRename()
                    }) {
                        Text("Rename")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)

                    if let onDelete = onDelete {
                        Button(action: {
                            showActions = false
                            onDelete()
                        }) {
                            Text("Delete")
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.windowBackgroundColor))
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .offset(y: 24)
                .zIndex(10)
            }
        }
    }
}
