import Cocoa
import FirebaseCore
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var timerPanelController: TimerPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Note: FirebaseApp.configure() is called in TaskGoApp.init()
        // to ensure it runs before @StateObject ViewModels are created.

        // Request notification permissions for timer alerts
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }

        // Initialize the floating timer panel controller
        timerPanelController = TimerPanelController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up timer panel
        timerPanelController?.close()
    }
}
