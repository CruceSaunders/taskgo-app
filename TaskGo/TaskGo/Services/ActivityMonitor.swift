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
/// When ActivityTracker is running, this subscribes to its events
/// via NotificationCenter instead of creating a separate CGEvent tap.
class ActivityMonitor: ObservableObject {
    static let shared = ActivityMonitor()

    @Published var isMonitoring = false
    @Published var hasPermission = false
    @Published var activityPercentage: Double = 0.0

    private let intervalSeconds: TimeInterval = 30
    let requiredActivityPercentage: Double = 0.60

    private var activityDetectedInCurrentInterval = false
    private var totalIntervals: Int = 0
    private var activeIntervals: Int = 0
    private var intervalTimer: Timer?

    private var activityObserver: Any?

    private init() {
        checkPermission()
    }

    // MARK: - Permission Checking

    func checkPermission() {
        hasPermission = ActivityTracker.shared.hasPermission
        if !hasPermission {
            let testTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
                callback: { _, _, event, _ in Unmanaged.passRetained(event) },
                userInfo: nil
            )
            if let tap = testTap {
                hasPermission = true
                CFMachPortInvalidate(tap)
            }
        }
    }

    func requestPermission() {
        ActivityTracker.shared.requestPermission()
    }

    // MARK: - Monitoring Control

    func startMonitoring() {
        guard !isMonitoring else { return }

        totalIntervals = 0
        activeIntervals = 0
        activityDetectedInCurrentInterval = false
        activityPercentage = 0.0

        activityObserver = NotificationCenter.default.addObserver(
            forName: .activityDetected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activityDetectedInCurrentInterval = true
        }

        isMonitoring = true
        hasPermission = true
        startIntervalTimer()
    }

    func stopMonitoring() -> (totalIntervals: Int, activeIntervals: Int, percentage: Double) {
        let result = (
            totalIntervals: totalIntervals,
            activeIntervals: activeIntervals,
            percentage: totalIntervals > 0 ? Double(activeIntervals) / Double(totalIntervals) : 0
        )

        if let observer = activityObserver {
            NotificationCenter.default.removeObserver(observer)
            activityObserver = nil
        }

        intervalTimer?.invalidate()
        intervalTimer = nil

        isMonitoring = false
        return result
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

        activityPercentage = totalIntervals > 0
            ? Double(activeIntervals) / Double(totalIntervals)
            : 0.0

        activityDetectedInCurrentInterval = false
    }

    // MARK: - XP Calculation

    func qualifiesForXP() -> Bool {
        return activityPercentage >= requiredActivityPercentage
    }

    func calculateEarnedXP(totalMinutes: Int) -> Int {
        guard qualifiesForXP() else { return 0 }
        let activeMinutes = Int(Double(totalMinutes) * activityPercentage)
        return XPSystem.calculateXP(activeMinutes: activeMinutes)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let activityDetected = Notification.Name("activityDetected")
}
