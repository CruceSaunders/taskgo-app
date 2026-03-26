import Foundation
import UserNotifications
import AppKit

enum FocusVerdict {
    case onTask
    case offTask
}

struct FocusSessionSummary {
    let taskName: String
    let duration: Int
    let totalChecks: Int
    let onTaskChecks: Int
    let focusScore: Double
    let notifications: Int
}

@MainActor
class FocusGuardService: ObservableObject {
    static let shared = FocusGuardService()

    @Published var isActive = false
    @Published var currentTask: TaskItem?
    @Published var taskContext = ""
    @Published var focusScore: Double = 100.0
    @Published var lastVerdict: FocusVerdict = .onTask
    @Published var timeElapsed: Int = 0
    @Published var totalChecks: Int = 0
    @Published var onTaskChecks: Int = 0
    @Published var offTaskNotifications: Int = 0

    var checkIntervalSeconds: Int {
        UserDefaults.standard.integer(forKey: "focusGuard_interval").clamped(to: 30...300, fallback: 60)
    }
    var offTaskThreshold: Int {
        UserDefaults.standard.integer(forKey: "focusGuard_threshold").clamped(to: 1...10, fallback: 2)
    }
    var cooldownSeconds: Int {
        UserDefaults.standard.integer(forKey: "focusGuard_cooldown").clamped(to: 30...600, fallback: 120)
    }

    private var checkTimer: DispatchSourceTimer?
    private var elapsedTimer: Timer?
    private var offTaskStreak = 0
    private var lastNotificationTime: Date = .distantPast
    private var isChecking = false
    private var isPaused = false
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?

    private init() {}

    func start(task: TaskItem, context: String = "") {
        currentTask = task
        taskContext = context
        isActive = true
        totalChecks = 0
        onTaskChecks = 0
        offTaskNotifications = 0
        offTaskStreak = 0
        timeElapsed = 0
        focusScore = 100.0
        lastVerdict = .onTask
        isPaused = false
        isChecking = false

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .seconds(checkIntervalSeconds), repeating: .seconds(checkIntervalSeconds))
        timer.setEventHandler { [weak self] in
            Task { @MainActor in self?.performCheck() }
        }
        timer.resume()
        checkTimer = timer

        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isPaused else { return }
                self.timeElapsed += 1
            }
        }

        observeSystemState()
    }

    func stop() -> FocusSessionSummary {
        let summary = buildSummary()
        tearDown()
        return summary
    }

    func completeTask() -> FocusSessionSummary {
        return stop()
    }

    func updateContext(_ newContext: String) {
        taskContext = newContext
    }

    func snooze(minutes: Int) {
        isPaused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(minutes * 60)) { [weak self] in
            Task { @MainActor in self?.isPaused = false }
        }
    }

    // MARK: - Check Logic

    private func performCheck() {
        guard isActive, !isPaused, !isChecking else { return }

        if WindowWatcher.shared.isIdle { return }

        guard let screenshotData = FocusScreenCapture.capture() else { return }

        let currentApp = WindowWatcher.shared.currentAppName
        let taskName = currentTask?.name ?? ""
        let context = taskContext

        isChecking = true

        Task {
            let verdict = await analyzeScreenshot(imageData: screenshotData, taskName: taskName, context: context, currentApp: currentApp)

            await MainActor.run {
                isChecking = false
                totalChecks += 1
                lastVerdict = verdict

                switch verdict {
                case .onTask:
                    onTaskChecks += 1
                    offTaskStreak = 0
                case .offTask:
                    offTaskStreak += 1
                    if offTaskStreak >= offTaskThreshold {
                        sendNotificationIfAllowed()
                    }
                }

                focusScore = totalChecks > 0
                    ? (Double(onTaskChecks) / Double(totalChecks)) * 100.0
                    : 100.0
            }
        }
    }

    private func analyzeScreenshot(imageData: Data, taskName: String, context: String, currentApp: String) async -> FocusVerdict {
        var prompt = "You are a focus monitor. The user has declared they are working on this task:\n\n"
        prompt += "TASK: \"\(taskName)\"\n"
        if !context.isEmpty {
            prompt += "ADDITIONAL CONTEXT: \"\(context)\"\n"
        }
        prompt += "\nThe user is currently in this application: \(currentApp)\n"
        prompt += "\nLook at the attached screenshot. Is the user currently working on their declared task?\n"
        prompt += "\nRespond with ONLY one word:\n- ON_TASK\n- OFF_TASK"

        do {
            let response = try await FocusGuardAI.analyze(prompt: prompt, imageData: imageData)
            let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return cleaned.contains("OFF_TASK") ? .offTask : .onTask
        } catch {
            return .onTask
        }
    }

    private func sendNotificationIfAllowed() {
        let now = Date()
        guard now.timeIntervalSince(lastNotificationTime) >= Double(cooldownSeconds) else { return }

        lastNotificationTime = now
        offTaskNotifications += 1

        let content = UNMutableNotificationContent()
        content.title = "Stay on Task"
        content.body = "You should be working on: \(currentTask?.name ?? "your task")"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "focusGuard-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - System State Observers

    private func observeSystemState() {
        let ws = NSWorkspace.shared.notificationCenter

        sleepObserver = ws.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isPaused = true }
        }
        wakeObserver = ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isPaused = false }
        }
        terminateObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            if self.isActive { _ = self.stop() }
        }
    }

    // MARK: - Helpers

    private func buildSummary() -> FocusSessionSummary {
        FocusSessionSummary(
            taskName: currentTask?.name ?? "",
            duration: timeElapsed,
            totalChecks: totalChecks,
            onTaskChecks: onTaskChecks,
            focusScore: focusScore,
            notifications: offTaskNotifications
        )
    }

    private func tearDown() {
        checkTimer?.cancel()
        checkTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        isActive = false
        currentTask = nil
        taskContext = ""
        isChecking = false
        isPaused = false

        if let o = sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(o) }
        if let o = wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(o) }
        if let o = terminateObserver { NotificationCenter.default.removeObserver(o) }
        sleepObserver = nil
        wakeObserver = nil
        terminateObserver = nil
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>, fallback: Int) -> Int {
        let v = self == 0 ? fallback : self
        return Swift.min(Swift.max(v, range.lowerBound), range.upperBound)
    }
}
