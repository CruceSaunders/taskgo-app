import SwiftUI
import FirebaseCore

@main
struct TaskGoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var taskViewModel: TaskViewModel
    @StateObject private var groupViewModel: GroupViewModel
    @StateObject private var taskGoViewModel: TaskGoViewModel
    @StateObject private var xpViewModel: XPViewModel
    // @StateObject private var socialViewModel: SocialViewModel  // v2: Social features deferred

    init() {
        // CRITICAL: Configure Firebase BEFORE any ViewModels that use Firestore
        FirebaseApp.configure()

        // Now safe to initialize ViewModels
        _authViewModel = StateObject(wrappedValue: AuthViewModel())
        _taskViewModel = StateObject(wrappedValue: TaskViewModel())
        _groupViewModel = StateObject(wrappedValue: GroupViewModel())
        _taskGoViewModel = StateObject(wrappedValue: TaskGoViewModel())
        _xpViewModel = StateObject(wrappedValue: XPViewModel())
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
                // .environmentObject(socialViewModel)  // v2: Social features deferred
        } label: {
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(authViewModel)
        }
    }
}
