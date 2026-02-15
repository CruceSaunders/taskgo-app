import SwiftUI

enum AppTab: String, CaseIterable {
    case tasks = "Tasks"
    case social = "Social"
    case profile = "Profile"
}

struct MainView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var taskVM: TaskViewModel
    @EnvironmentObject var groupVM: GroupViewModel
    @EnvironmentObject var taskGoVM: TaskGoViewModel
    @EnvironmentObject var xpVM: XPViewModel
    @EnvironmentObject var socialVM: SocialViewModel

    @State private var selectedTab: AppTab = .tasks

    @State private var showActivityPermission = false

    var body: some View {
        VStack(spacing: 0) {
            // Error banner
            ErrorBannerView()

            // Header with Task Go button and level
            headerView

            Divider()

            // Tab selector
            tabBar

            Divider()

            // Tab content
            switch selectedTab {
            case .tasks:
                TasksTabView()
            case .social:
                SocialTabView()
            case .profile:
                ProfileTabView()
            }
        }
        .onAppear {
            groupVM.startListening()
            socialVM.startListening()
            Task { await xpVM.loadXP() }
            KeyboardShortcutModifiers.registerGlobalHotkey {}
        }
        .onDisappear {
            groupVM.stopListening()
            taskVM.stopListening()
            socialVM.stopListening()
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
        .sheet(isPresented: $showActivityPermission) {
            ActivityPermissionView(isPresented: $showActivityPermission)
                .environmentObject(taskGoVM)
        }
    }

    private func toggleTaskGo() {
        if taskGoVM.isActive {
            taskGoVM.stopTaskGo()
        } else {
            // Check activity permission first time
            if !taskGoVM.hasActivityPermission && !UserDefaults.standard.bool(forKey: "hasSeenActivityPermission") {
                UserDefaults.standard.set(true, forKey: "hasSeenActivityPermission")
                showActivityPermission = true
            }
            if let firstTask = taskVM.firstIncompleteTask {
                taskGoVM.startTaskGo(with: firstTask)
            }
        }
    }

    private func completeCurrentTask() {
        guard let result = taskGoVM.completeCurrentTask() else { return }

        // Award XP
        Task {
            await xpVM.awardXP(activeMinutes: result.activeMinutes)
            await taskVM.toggleComplete(result.task)

            // Advance to next task if Task Go is active
            if taskGoVM.isActive, let nextTask = taskVM.firstIncompleteTask {
                taskGoVM.advanceToNextTask(nextTask)
            } else {
                taskGoVM.stopTaskGo()
            }
        }
    }

    private var headerView: some View {
        HStack {
            // Level badge
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
                        .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? Color.calmTeal : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            selectedTab == tab
                                ? Color.calmTeal.opacity(0.1)
                                : Color.clear
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
