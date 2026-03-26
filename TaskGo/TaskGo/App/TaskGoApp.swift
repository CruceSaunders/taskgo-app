import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@main
struct TaskGoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var taskViewModel: TaskViewModel
    @StateObject private var groupViewModel: GroupViewModel
    @StateObject private var taskGoViewModel: TaskGoViewModel
    @StateObject private var xpViewModel: XPViewModel
    @StateObject private var notesViewModel: NotesViewModel
    @StateObject private var calendarViewModel: CalendarViewModel
    @StateObject private var reminderViewModel: ReminderViewModel
    @StateObject private var plannerViewModel: PlannerViewModel
    @StateObject private var pomodoroViewModel: PomodoroViewModel
    @StateObject private var activityViewModel: ActivityViewModel
    @StateObject private var focusGuardViewModel: FocusGuardViewModel

    init() {
        FirebaseApp.configure()
        let settings = Firestore.firestore().settings
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
        try? Auth.auth().useUserAccessGroup(nil)

        _authViewModel = StateObject(wrappedValue: AuthViewModel())
        _taskViewModel = StateObject(wrappedValue: TaskViewModel())
        _groupViewModel = StateObject(wrappedValue: GroupViewModel())
        _taskGoViewModel = StateObject(wrappedValue: TaskGoViewModel())
        _xpViewModel = StateObject(wrappedValue: XPViewModel())
        _notesViewModel = StateObject(wrappedValue: NotesViewModel())
        _calendarViewModel = StateObject(wrappedValue: CalendarViewModel())
        _reminderViewModel = StateObject(wrappedValue: ReminderViewModel())
        _plannerViewModel = StateObject(wrappedValue: PlannerViewModel())
        _pomodoroViewModel = StateObject(wrappedValue: PomodoroViewModel())
        _activityViewModel = StateObject(wrappedValue: ActivityViewModel())
        _focusGuardViewModel = StateObject(wrappedValue: FocusGuardViewModel())
    }

    var body: some Scene {
        let _ = ensureSetup()

        MenuBarExtra {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(taskViewModel)
                .environmentObject(groupViewModel)
                .environmentObject(taskGoViewModel)
                .environmentObject(xpViewModel)
                .environmentObject(notesViewModel)
                .environmentObject(calendarViewModel)
                .environmentObject(reminderViewModel)
                .environmentObject(plannerViewModel)
                .environmentObject(pomodoroViewModel)
                .environmentObject(activityViewModel)
                .environmentObject(focusGuardViewModel)
                .onAppear {
                    appDelegate.timerPanelController?.setViewModel(taskGoViewModel)
                    appDelegate.pomodoroPanelController?.setViewModel(pomodoroViewModel)
                    taskGoViewModel.taskVM = taskViewModel
                    taskGoViewModel.xpVM = xpViewModel
                    RecurrenceService.shared.start()
                    plannerViewModel.startListening()
                }
        } label: {
            Image(systemName: "bolt.circle.fill")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(authViewModel)
        }
    }

    @State private var hasSetup = false

    private func ensureSetup() {
        guard !hasSetup else { return }
        DispatchQueue.main.async {
            hasSetup = true
            setupMainWindowContentHandler()
        }
    }

    private func setupMainWindowContentHandler() {
        NotificationCenter.default.addObserver(
            forName: .mainWindowNeedsContent,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            let contentView = MainWindowView()
                .environmentObject(self.authViewModel)
                .environmentObject(self.taskViewModel)
                .environmentObject(self.groupViewModel)
                .environmentObject(self.taskGoViewModel)
                .environmentObject(self.xpViewModel)
                .environmentObject(self.notesViewModel)
                .environmentObject(self.calendarViewModel)
                .environmentObject(self.reminderViewModel)
                .environmentObject(self.plannerViewModel)
                .environmentObject(self.pomodoroViewModel)
                .environmentObject(self.activityViewModel)
                .environmentObject(self.focusGuardViewModel)
            window.contentView = NSHostingView(rootView: contentView)
        }
    }
}
