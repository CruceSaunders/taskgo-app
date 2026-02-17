import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct TaskGoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var taskViewModel: TaskViewModel
    @StateObject private var groupViewModel: GroupViewModel
    @StateObject private var taskGoViewModel: TaskGoViewModel
    @StateObject private var xpViewModel: XPViewModel
    @StateObject private var notesViewModel: NotesViewModel
    // @StateObject private var socialViewModel: SocialViewModel  // v2: Social features deferred

    init() {
        // CRITICAL: Configure Firebase BEFORE any ViewModels that use Firestore
        FirebaseApp.configure()

        // Use default keychain access group for non-App-Store distribution
        try? Auth.auth().useUserAccessGroup(nil)

        // Now safe to initialize ViewModels
        _authViewModel = StateObject(wrappedValue: AuthViewModel())
        _taskViewModel = StateObject(wrappedValue: TaskViewModel())
        _groupViewModel = StateObject(wrappedValue: GroupViewModel())
        _taskGoViewModel = StateObject(wrappedValue: TaskGoViewModel())
        _xpViewModel = StateObject(wrappedValue: XPViewModel())
        _notesViewModel = StateObject(wrappedValue: NotesViewModel())
        // _socialViewModel = StateObject(wrappedValue: SocialViewModel())  // v2
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(taskViewModel)
                .environmentObject(groupViewModel)
                .environmentObject(taskGoViewModel)
                .environmentObject(xpViewModel)
                .environmentObject(notesViewModel)
                .onAppear {
                    appDelegate.timerPanelController?.setViewModel(taskGoViewModel)
                    taskGoViewModel.taskVM = taskViewModel
                    taskGoViewModel.xpVM = xpViewModel
                    setupMainWindowContentHandler()
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
            window.contentView = NSHostingView(rootView: contentView)
        }
    }
}
