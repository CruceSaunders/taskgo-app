import SwiftUI
import FirebaseCore

@main
struct TaskGoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var taskViewModel = TaskViewModel()
    @StateObject private var groupViewModel = GroupViewModel()
    @StateObject private var taskGoViewModel = TaskGoViewModel()
    @StateObject private var xpViewModel = XPViewModel()
    @StateObject private var socialViewModel = SocialViewModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(taskViewModel)
                .environmentObject(groupViewModel)
                .environmentObject(taskGoViewModel)
                .environmentObject(xpViewModel)
                .environmentObject(socialViewModel)
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
