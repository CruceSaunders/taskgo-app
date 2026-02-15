import Foundation
import AppKit
import IOKit
import IOKit.hid

/// Monitors keyboard and mouse activity during Task Go sessions.
/// Used to verify that the user is actually working (for fair XP awards).
///
/// Privacy-first design:
/// - Only detects THAT input occurred, never WHAT was typed/clicked
/// - Uses Input Monitoring permission (less scary than Accessibility)
/// - Tracks activity in 30-second intervals
/// - Requires 60% active intervals to award XP
///
/// Technical approach:
/// - Primary: IOHIDManager for global keyboard/mouse event detection
/// - Fallback: CGEvent tap if IOHIDManager doesn't work for our use case
/// - Last resort: NSEvent global monitor (requires Accessibility)
class ActivityMonitor: ObservableObject {
    static let shared = ActivityMonitor()

    @Published var isMonitoring = false
    @Published var hasPermission = false
    @Published var activityPercentage: Double = 0.0

    /// Interval length in seconds for activity checks
    private let intervalSeconds: TimeInterval = 30

    /// Minimum percentage of active intervals to award XP
    let requiredActivityPercentage: Double = 0.60

    /// Track activity per interval
    private var activityDetectedInCurrentInterval = false
    private var totalIntervals: Int = 0
    private var activeIntervals: Int = 0
    private var intervalTimer: Timer?

    /// IOHIDManager for input monitoring
    private var hidManager: IOHIDManager?

    /// CGEvent tap as fallback
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Global NSEvent monitors as last resort
    private var keyboardMonitor: Any?
    private var mouseMonitor: Any?

    private init() {
        checkPermission()
    }

    // MARK: - Permission Checking

    /// Check if we have Input Monitoring permission
    func checkPermission() {
        // Try to create a CGEvent tap to check permission
        // If it fails, we don't have permission
        let testTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, _, event, _ in
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        )

        if let tap = testTap {
            hasPermission = true
            // Clean up test tap
            CFMachPortInvalidate(tap)
        } else {
            // Try IOHIDManager approach
            hasPermission = checkIOHIDPermission()
        }
    }

    private func checkIOHIDPermission() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, nil)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        return result == kIOReturnSuccess
    }

    /// Request Input Monitoring permission from the user
    func requestPermission() {
        // Opening System Preferences to the Input Monitoring pane
        // The user must manually add the app
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Monitoring Control

    func startMonitoring() {
        guard !isMonitoring else { return }

        // Reset counters
        totalIntervals = 0
        activeIntervals = 0
        activityDetectedInCurrentInterval = false
        activityPercentage = 0.0

        // Try monitoring approaches in order of preference
        if startCGEventTapMonitoring() {
            isMonitoring = true
        } else if startIOHIDMonitoring() {
            isMonitoring = true
        } else if startNSEventMonitoring() {
            isMonitoring = true
        } else {
            // No monitoring available - XP will not be awarded
            hasPermission = false
            return
        }

        // Start interval timer
        startIntervalTimer()
    }

    func stopMonitoring() -> (totalIntervals: Int, activeIntervals: Int, percentage: Double) {
        let result = (
            totalIntervals: totalIntervals,
            activeIntervals: activeIntervals,
            percentage: totalIntervals > 0 ? Double(activeIntervals) / Double(totalIntervals) : 0
        )

        // Clean up CGEvent tap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }

        // Clean up IOHIDManager
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            hidManager = nil
        }

        // Clean up NSEvent monitors
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }

        // Stop interval timer
        intervalTimer?.invalidate()
        intervalTimer = nil

        isMonitoring = false
        return result
    }

    // MARK: - CGEvent Tap (Primary approach)

    private func startCGEventTapMonitoring() -> Bool {
        let eventMask: CGEventMask = (
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)
        )

        // Use a static callback that posts a notification
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, _ in
                // Post notification that activity was detected
                NotificationCenter.default.post(name: .activityDetected, object: nil)
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        )

        guard let eventTap = tap else {
            return false
        }

        self.eventTap = eventTap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        self.runLoopSource = runLoopSource

        // Listen for activity notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onActivityDetected),
            name: .activityDetected,
            object: nil
        )

        hasPermission = true
        return true
    }

    // MARK: - IOHIDManager (Fallback)

    private func startIOHIDMonitoring() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        // Match keyboard and mouse devices
        let keyboard: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
        ]
        let mouse: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Mouse
        ]

        IOHIDManagerSetDeviceMatchingMultiple(manager, [keyboard, mouse] as CFArray)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            return false
        }

        // Register input value callback
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, _ in
            guard let context = context else { return }
            let monitor = Unmanaged<ActivityMonitor>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                monitor.onActivityDetectedDirect()
            }
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)

        self.hidManager = manager
        hasPermission = true
        return true
    }

    // MARK: - NSEvent Global Monitor (Last resort - requires Accessibility)

    private func startNSEventMonitoring() -> Bool {
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] _ in
            self?.onActivityDetectedDirect()
        }

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel]) { [weak self] _ in
            self?.onActivityDetectedDirect()
        }

        // If monitors are nil, we don't have Accessibility permission
        if keyboardMonitor == nil && mouseMonitor == nil {
            return false
        }

        hasPermission = true
        return true
    }

    // MARK: - Activity Detection

    @objc private func onActivityDetected() {
        activityDetectedInCurrentInterval = true
    }

    private func onActivityDetectedDirect() {
        activityDetectedInCurrentInterval = true
    }

    // MARK: - Interval Timer

    private func startIntervalTimer() {
        intervalTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            self?.recordInterval()
        }
    }

    private func recordInterval() {
        totalIntervals += 1

        if activityDetectedInCurrentInterval {
            activeIntervals += 1
        }

        // Update percentage
        activityPercentage = totalIntervals > 0
            ? Double(activeIntervals) / Double(totalIntervals)
            : 0.0

        // Reset for next interval
        activityDetectedInCurrentInterval = false
    }

    // MARK: - XP Calculation

    /// Determine if user qualifies for XP based on activity
    func qualifiesForXP() -> Bool {
        return activityPercentage >= requiredActivityPercentage
    }

    /// Calculate XP earned based on active time
    func calculateEarnedXP(totalMinutes: Int) -> Int {
        guard qualifiesForXP() else { return 0 }
        // Award XP proportional to active time
        let activeMinutes = Int(Double(totalMinutes) * activityPercentage)
        return XPSystem.calculateXP(activeMinutes: activeMinutes)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let activityDetected = Notification.Name("activityDetected")
}
