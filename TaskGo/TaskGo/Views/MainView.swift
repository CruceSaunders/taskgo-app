import SwiftUI

enum AppTab: String, CaseIterable {
    case tasks = "Tasks"
    case notes = "Notes"
    case planner = "Planner"
    case calendar = "Calendar"
    case goals = "Goals"
    case profile = "Profile"
}

struct MainView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var taskVM: TaskViewModel
    @EnvironmentObject var groupVM: GroupViewModel
    @EnvironmentObject var taskGoVM: TaskGoViewModel
    @EnvironmentObject var xpVM: XPViewModel
    @EnvironmentObject var pomodoroVM: PomodoroViewModel

    @State private var selectedTab: AppTab = .tasks

    var body: some View {
        VStack(spacing: 0) {
            ErrorBannerView()

            headerView

            Divider()

            tabBar

            Divider()

            switch selectedTab {
            case .tasks:
                TasksTabView()
            case .notes:
                NotesTabView()
            case .planner:
                PlannerTabView()
            case .calendar:
                CalendarTabView()
            case .goals:
                GoalsTabView()
            case .profile:
                ProfileTabView()
            }
        }
        .onAppear {
            groupVM.startListening()
            Task { await xpVM.loadXP() }
            KeyboardShortcutModifiers.registerGlobalHotkey {}
        }
        .onDisappear {
            groupVM.stopListening()
            taskVM.stopListening()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutToggleTaskGo)) { _ in
            toggleTaskGo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutTogglePause)) { _ in
            taskGoVM.togglePause()
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskGoCompleteTask)) { _ in
            completeCurrentTask()
        }
    }

    private func toggleTaskGo() {
        if taskGoVM.isActive {
            taskGoVM.stopTaskGo()
        } else {
            let allIds = Set(taskVM.incompleteTasksForDisplay.compactMap { $0.id })
            if !allIds.isEmpty {
                taskGoVM.startTaskGoWithSelected(allIds)
            }
        }
    }

    private func completeCurrentTask() {
        guard let result = taskGoVM.completeCurrentTask() else { return }

        Task {
            await xpVM.awardXP(activeMinutes: result.activeMinutes)
            await taskVM.toggleComplete(result.task)

            if taskGoVM.isActive, let nextTask = taskVM.firstIncompleteTask {
                taskGoVM.advanceToNextTask(nextTask)
            } else {
                taskGoVM.stopTaskGo()
            }
        }
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.amber)
                Text("Lv.\(xpVM.level)")
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.amber.opacity(0.15))
            .clipShape(Capsule())

            Spacer()

            Button(action: {
                NotificationCenter.default.post(name: .openMainWindow, object: nil)
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 9))
                    Text("Open")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.primary.opacity(0.5))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)

            Button(action: {
                if pomodoroVM.isActive {
                    pomodoroVM.stop()
                } else {
                    pomodoroVM.start()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: pomodoroVM.isActive ? "stop.fill" : "timer")
                        .font(.system(size: 10))
                    Text(pomodoroVM.isActive ? pomodoroVM.formattedTime : "Pomodoro")
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(pomodoroVM.isActive ? Color.pomodoroRed : Color.pomodoroRed.opacity(0.85))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button(action: {
                if taskGoVM.isActive {
                    taskGoVM.stopTaskGo()
                } else {
                    if let firstTask = taskVM.firstIncompleteTask {
                        taskGoVM.startTaskGo(with: firstTask)
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: taskGoVM.isActive ? "stop.fill" : "bolt.fill")
                        .font(.system(size: 10))
                    Text(taskGoVM.isActive ? "Stop" : "Task Go!")
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(taskGoVM.isActive ? Color.red.opacity(0.9) : Color.calmTeal)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(taskVM.firstIncompleteTask == nil && !taskGoVM.isActive)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? Color.calmTeal : .primary.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            selectedTab == tab
                                ? Color.calmTeal.opacity(0.15)
                                : Color.clear
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
