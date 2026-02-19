import Cocoa
import SwiftUI
import FirebaseCore
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var timerPanelController: TimerPanelController?
    var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let notifCenter = UNUserNotificationCenter.current()
        notifCenter.delegate = self
        notifCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }

        timerPanelController = TimerPanelController()

        // Listen for open window requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openMainWindow),
            name: .openMainWindow,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        timerPanelController?.close()
    }

    @objc func openMainWindow() {
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 550),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TaskGo!"
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("TaskGoMainWindow")
        window.minSize = NSSize(width: 500, height: 400)

        // Show dock icon when window is open
        NSApp.setActivationPolicy(.regular)

        mainWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Set the content -- will be set by TaskGoApp after VMs are ready
        NotificationCenter.default.post(name: .mainWindowNeedsContent, object: window)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])

        // Play alarm for reminders
        if notification.request.content.categoryIdentifier == "REMINDER" {
            NotificationScheduler.shared.playAlarmSound()
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // User tapped the notification -- open the app
        NSApp.activate(ignoringOtherApps: true)
        completionHandler()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openMainWindow()
        }
        return true
    }
}

extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
    static let mainWindowNeedsContent = Notification.Name("mainWindowNeedsContent")
}
