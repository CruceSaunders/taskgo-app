import SwiftUI
import Carbon.HIToolbox

/// Keyboard shortcuts for power users
struct KeyboardShortcutModifiers {
    /// Register global hotkey to toggle the popover (Cmd+Shift+T)
    static func registerGlobalHotkey(action: @escaping () -> Void) {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Cmd+N: New task (when popover is open)
            if event.modifierFlags.contains(.command) && event.keyCode == kVK_ANSI_N {
                NotificationCenter.default.post(name: .shortcutNewTask, object: nil)
                return nil
            }

            // Cmd+G: Toggle Task Go
            if event.modifierFlags.contains(.command) && event.keyCode == kVK_ANSI_G {
                NotificationCenter.default.post(name: .shortcutToggleTaskGo, object: nil)
                return nil
            }

            // Cmd+P: Pause/Resume timer
            if event.modifierFlags.contains(.command) && event.keyCode == kVK_ANSI_P {
                NotificationCenter.default.post(name: .shortcutTogglePause, object: nil)
                return nil
            }

            // Cmd+1-9: Switch to group tab
            if event.modifierFlags.contains(.command) {
                let numberKeys: [UInt16] = [
                    UInt16(kVK_ANSI_1), UInt16(kVK_ANSI_2), UInt16(kVK_ANSI_3),
                    UInt16(kVK_ANSI_4), UInt16(kVK_ANSI_5), UInt16(kVK_ANSI_6),
                    UInt16(kVK_ANSI_7), UInt16(kVK_ANSI_8), UInt16(kVK_ANSI_9)
                ]
                if let index = numberKeys.firstIndex(of: event.keyCode) {
                    NotificationCenter.default.post(
                        name: .shortcutSwitchGroup,
                        object: nil,
                        userInfo: ["index": index]
                    )
                    return nil
                }
            }

            return event
        }
    }
}

// MARK: - Shortcut Notification Names

extension Notification.Name {
    static let shortcutNewTask = Notification.Name("shortcutNewTask")
    static let shortcutToggleTaskGo = Notification.Name("shortcutToggleTaskGo")
    static let shortcutTogglePause = Notification.Name("shortcutTogglePause")
    static let shortcutSwitchGroup = Notification.Name("shortcutSwitchGroup")
}
