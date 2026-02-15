import Foundation
import Combine
import AppKit

enum TaskGoState: Equatable {
    case idle
    case running
    case paused
    case expired
}

@MainActor
class TaskGoViewModel: ObservableObject {
    @Published var state: TaskGoState = .idle
    @Published var currentTask: TaskItem?
    @Published var timeRemaining: Int = 0 // seconds
    @Published var totalTime: Int = 0 // seconds
    @Published var isActive = false // Task Go toggle
    @Published var elapsedActiveMinutes: Int = 0

    private var timer: Timer?
    private var elapsedSeconds: Int = 0
    private var alarmPlayer: NSSound?

    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return Double(totalTime - timeRemaining) / Double(totalTime)
    }

    var timeRemainingFormatted: String {
        let minutes = abs(timeRemaining) / 60
        let seconds = abs(timeRemaining) % 60
        let sign = timeRemaining < 0 ? "-" : ""
        return String(format: "%@%d:%02d", sign, minutes, seconds)
    }

    var isExpired: Bool {
        state == .expired
    }

    // MARK: - Task Go Control

    func startTaskGo(with task: TaskItem) {
        currentTask = task
        totalTime = task.timeEstimate
        timeRemaining = task.timeEstimate
        elapsedSeconds = 0
        elapsedActiveMinutes = 0
        state = .running
        isActive = true
        startTimer()
        showTimerPanel()
    }

    func stopTaskGo() {
        state = .idle
        isActive = false
        currentTask = nil
        timeRemaining = 0
        totalTime = 0
        elapsedSeconds = 0
        elapsedActiveMinutes = 0
        stopTimer()
        stopAlarm()
        hideTimerPanel()
    }

    func pauseTimer() {
        guard state == .running else { return }
        state = .paused
        stopTimer()
    }

    func resumeTimer() {
        guard state == .paused else { return }
        state = .running
        startTimer()
    }

    func togglePause() {
        if state == .running {
            pauseTimer()
        } else if state == .paused {
            resumeTimer()
        }
    }

    func addMoreTime(_ seconds: Int) {
        timeRemaining += seconds
        totalTime += seconds
        state = .running
        stopAlarm()
        startTimer()
    }

    func completeCurrentTask() -> (task: TaskItem, activeMinutes: Int)? {
        guard let task = currentTask else { return nil }
        let minutes = elapsedSeconds / 60
        stopAlarm()
        return (task: task, activeMinutes: minutes)
    }

    func advanceToNextTask(_ task: TaskItem) {
        stopTimer()
        stopAlarm()
        startTaskGo(with: task)
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard state == .running else { return }

        timeRemaining -= 1
        elapsedSeconds += 1

        // Update active minutes (tracked for XP)
        elapsedActiveMinutes = elapsedSeconds / 60

        if timeRemaining <= 0 && state == .running {
            timerExpired()
        }
    }

    private func timerExpired() {
        state = .expired
        stopTimer()
        playAlarm()
        triggerBounceAnimation()
    }

    // MARK: - Alarm

    private func playAlarm() {
        // Check if Focus/DND is active
        if !isFocusModeActive() {
            // Play a gentle chime sound
            if let soundURL = Bundle.main.url(forResource: "gentle_chime", withExtension: "aiff") {
                alarmPlayer = NSSound(contentsOf: soundURL, byReference: true)
            } else {
                // Fallback to system sound
                alarmPlayer = NSSound(named: "Glass")
            }
            alarmPlayer?.play()

            // Stop sound after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.alarmPlayer?.stop()
            }
        }
    }

    private func stopAlarm() {
        alarmPlayer?.stop()
        alarmPlayer = nil
    }

    private func isFocusModeActive() -> Bool {
        // Check macOS Focus/DND status
        // Uses the private NSDoNotDisturb API - may need adjustment
        // Check macOS Focus/DND status
        // Using DistributedNotificationCenter to detect Focus mode
        // This will be refined in the Polish phase with proper DND detection
        _ = DistributedNotificationCenter.default()
        return false
    }

    private func triggerBounceAnimation() {
        // Notification to the timer panel to start bouncing
        NotificationCenter.default.post(name: .taskGoTimerExpired, object: nil)
    }

    // MARK: - Timer Panel

    private func showTimerPanel() {
        NotificationCenter.default.post(name: .taskGoShowPanel, object: nil)
    }

    private func hideTimerPanel() {
        NotificationCenter.default.post(name: .taskGoHidePanel, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let taskGoTimerExpired = Notification.Name("taskGoTimerExpired")
    static let taskGoShowPanel = Notification.Name("taskGoShowPanel")
    static let taskGoHidePanel = Notification.Name("taskGoHidePanel")
}
