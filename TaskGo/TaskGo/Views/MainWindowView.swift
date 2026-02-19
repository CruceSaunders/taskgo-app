import SwiftUI

/// Full-size window interface -- same data as menu bar, bigger layout
struct MainWindowView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var taskVM: TaskViewModel
    @EnvironmentObject var groupVM: GroupViewModel
    @EnvironmentObject var taskGoVM: TaskGoViewModel
    @EnvironmentObject var xpVM: XPViewModel
    @EnvironmentObject var notesVM: NotesViewModel

    @State private var selectedTab: AppTab = .tasks

    var body: some View {
        if !authVM.isAuthenticated {
            AuthView()
                .frame(minWidth: 400, minHeight: 350)
                .background(Color(.windowBackgroundColor))
        } else {
            HSplitView {
                // Sidebar
                sidebar
                    .frame(minWidth: 160, maxWidth: 200)

                // Main content
                VStack(spacing: 0) {
                    switch selectedTab {
                    case .tasks:
                        TasksTabView()
                    case .notes:
                        NotesTabView()
                    case .calendar:
                        CalendarTabView()
                    case .profile:
                        ProfileTabView()
                    }
                }
                .frame(minWidth: 450)
            }
            .background(Color(.windowBackgroundColor))
            .onAppear {
                groupVM.startListening()
                Task { await xpVM.loadXP() }
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App header
            HStack(spacing: 8) {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.calmTeal)
                VStack(alignment: .leading, spacing: 1) {
                    Text("TaskGo!")
                        .font(.system(size: 14, weight: .bold))
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.amber)
                        Text("Lv.\(xpVM.level)")
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Nav items
            VStack(spacing: 2) {
                sidebarButton("Tasks", icon: "checklist", tab: .tasks)
                sidebarButton("Notes", icon: "doc.text", tab: .notes)
                sidebarButton("Calendar", icon: "calendar", tab: .calendar)
                sidebarButton("Profile", icon: "person.circle", tab: .profile)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Spacer()

            // Task Go button
            Button(action: {
                if taskGoVM.isActive {
                    taskGoVM.stopTaskGo()
                } else {
                    if let firstTask = taskVM.firstIncompleteTask {
                        taskGoVM.startTaskGo(with: firstTask)
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: taskGoVM.isActive ? "stop.fill" : "bolt.fill")
                        .font(.system(size: 12))
                    Text(taskGoVM.isActive ? "Stop" : "Task Go!")
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(taskGoVM.isActive ? Color.red.opacity(0.9) : Color.calmTeal)
                .foregroundStyle(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(taskVM.firstIncompleteTask == nil && !taskGoVM.isActive)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color.secondary.opacity(0.04))
    }

    private func sidebarButton(_ label: String, icon: String, tab: AppTab) -> some View {
        Button(action: { selectedTab = tab }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selectedTab == tab ? Color.calmTeal.opacity(0.12) : Color.clear)
            .foregroundStyle(selectedTab == tab ? Color.calmTeal : .primary.opacity(0.7))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
