import SwiftUI
import Combine

@MainActor
class PomodoroViewModel: ObservableObject {

    enum SessionType: String {
        case work = "Work"
        case breakTime = "Break"
    }

    enum TimerStatus {
        case idle, running, paused
    }

    static let workDuration = 25 * 60
    static let breakDuration = 5 * 60

    @Published var status: TimerStatus = .idle
    @Published var sessionType: SessionType = .work
    @Published var timeRemaining: Int = workDuration
    @Published var completedPomodoros: Int = 0

    private var timer: Timer?

    var isActive: Bool { status != .idle }
    var isPaused: Bool { status == .paused }

    var progress: Double {
        let total = sessionType == .work
            ? Double(Self.workDuration)
            : Double(Self.breakDuration)
        guard total > 0 else { return 0 }
        return 1.0 - Double(timeRemaining) / total
    }

    var formattedTime: String {
        let m = timeRemaining / 60
        let s = timeRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    func start() {
        sessionType = .work
        timeRemaining = Self.workDuration
        completedPomodoros = 0
        status = .running
        startTicking()
    }

    func togglePause() {
        guard isActive else { return }
        if status == .running {
            status = .paused
            timer?.invalidate()
            timer = nil
        } else {
            status = .running
            startTicking()
        }
    }

    func stop() {
        status = .idle
        sessionType = .work
        timeRemaining = Self.workDuration
        timer?.invalidate()
        timer = nil
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard timeRemaining > 0 else {
            timer?.invalidate()
            timer = nil
            switchSession()
            return
        }
        timeRemaining -= 1
    }

    private func switchSession() {
        if sessionType == .work {
            completedPomodoros += 1
            sessionType = .breakTime
            timeRemaining = Self.breakDuration
        } else {
            sessionType = .work
            timeRemaining = Self.workDuration
        }
        status = .running
        startTicking()
    }
}
