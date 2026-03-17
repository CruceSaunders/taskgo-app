import Foundation
import Combine
import AppKit
import SwiftUI

enum TaskGoState: Equatable {
    case idle
    case running
    case paused
    case expired
}

// MARK: - Lane

@MainActor
class TaskGoLane: ObservableObject, Identifiable {
    let id = UUID()
    let color: NSColor

    @Published var currentTask: TaskItem?
    @Published var state: TaskGoState = .idle
    @Published var timeRemaining: Int = 0
    @Published var totalTime: Int = 0
    @Published var elapsedActiveMinutes: Int = 0

    var selectedTaskIds: Set<String>
    var elapsedSeconds: Int = 0
    var completedTaskIds: Set<String> = []
    var isProcessingCompletion = false
    private var timer: Timer?

    static let laneColors: [NSColor] = [
        NSColor(red: 0.27, green: 0.71, blue: 0.67, alpha: 1), // teal
        NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1),   // orange
        NSColor(red: 0.58, green: 0.39, blue: 0.87, alpha: 1), // purple
        NSColor(red: 0.90, green: 0.30, blue: 0.36, alpha: 1), // coral
        NSColor(red: 0.20, green: 0.60, blue: 0.86, alpha: 1), // blue
    ]

    init(taskIds: Set<String>, colorIndex: Int) {
        self.selectedTaskIds = taskIds
        self.color = Self.laneColors[colorIndex % Self.laneColors.count]
    }

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

    var isExpired: Bool { state == .expired }
    var isFinished: Bool { state == .idle && currentTask == nil }

    var swiftUIColor: Color { Color(color) }

    // MARK: Lane Timer

    func startTimer(onTick: @escaping (TaskGoLane) -> Void) {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                onTick(self)
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func beginTask(_ task: TaskItem) {
        currentTask = task
        let time = task.effectiveTimeEstimate
        totalTime = time
        timeRemaining = time
        elapsedSeconds = 0
        elapsedActiveMinutes = 0
        state = .running
    }

    func reset() {
        stopTimer()
        state = .idle
        currentTask = nil
        timeRemaining = 0
        totalTime = 0
        elapsedSeconds = 0
        elapsedActiveMinutes = 0
        completedTaskIds.removeAll()
        isProcessingCompletion = false
    }
}

// MARK: - ViewModel

@MainActor
class TaskGoViewModel: ObservableObject {
    @Published var lanes: [TaskGoLane] = []
    @Published var isActive = false
    @Published var hasActivityPermission = false

    private var alarmPlayer: NSSound?
    private let activityMonitor = ActivityMonitor.shared
    private var laneCancellables: [UUID: AnyCancellable] = [:]

    weak var taskVM: TaskViewModel?
    weak var xpVM: XPViewModel?

    // Legacy single-lane convenience accessors (used by MainView header button)
    var currentTask: TaskItem? { lanes.first?.currentTask }
    var state: TaskGoState { lanes.first?.state ?? .idle }
    var timeRemaining: Int { lanes.first?.timeRemaining ?? 0 }
    var totalTime: Int { lanes.first?.totalTime ?? 0 }
    var progress: Double { lanes.first?.progress ?? 0 }
    var timeRemainingFormatted: String { lanes.first?.timeRemainingFormatted ?? "0:00" }
    var isExpired: Bool { lanes.first?.isExpired ?? false }
    var elapsedActiveMinutes: Int { lanes.first?.elapsedActiveMinutes ?? 0 }
    var activityPercentage: Double { 0.0 }

    var allTaskIdsInUse: Set<String> {
        var ids = Set<String>()
        for lane in lanes {
            ids.formUnion(lane.selectedTaskIds)
            ids.formUnion(lane.completedTaskIds)
        }
        return ids
    }

    // MARK: - Start / Add Lane

    func startTaskGo(with task: TaskItem) {
        let taskIds: Set<String> = [task.id].compactMap { $0 }.reduce(into: Set<String>()) { $0.insert($1) }
        startLane(taskIds: taskIds)
    }

    func startTaskGoWithSelected(_ taskIds: Set<String>) {
        startLane(taskIds: taskIds)
    }

    func addLane(taskIds: Set<String>) {
        startLane(taskIds: taskIds)
    }

    private func startLane(taskIds: Set<String>) {
        let filtered = taskIds.subtracting(allTaskIdsInUse)
        guard !filtered.isEmpty else { return }

        let lane = TaskGoLane(taskIds: filtered, colorIndex: lanes.count)

        let firstTask = resolveFirstTask(for: lane)
        guard let task = firstTask else { return }

        lane.beginTask(task)
        lanes.append(lane)
        isActive = true
        hasActivityPermission = activityMonitor.hasPermission

        observeLane(lane)
        lane.startTimer { [weak self] l in self?.tickLane(l) }

        if lanes.count == 1 {
            if activityMonitor.hasPermission { activityMonitor.startMonitoring() }
            showTimerPanel()
        }
        notifyPanelResize()
        WindowWatcher.shared.activeTaskName = task.name
    }

    // MARK: - Stop

    func stopTaskGo() {
        if activityMonitor.isMonitoring { _ = activityMonitor.stopMonitoring() }
        for lane in lanes { lane.reset() }
        lanes.removeAll()
        laneCancellables.removeAll()
        isActive = false
        stopAlarm()
        hideTimerPanel()
        WindowWatcher.shared.activeTaskName = nil
    }

    func removeLane(_ lane: TaskGoLane) {
        lane.reset()
        lanes.removeAll { $0.id == lane.id }
        laneCancellables.removeValue(forKey: lane.id)
        notifyPanelResize()
        if lanes.isEmpty { stopTaskGo() }
    }

    // MARK: - Lane Controls

    func togglePause(lane: TaskGoLane? = nil) {
        let target = lane ?? lanes.first
        guard let l = target else { return }
        if l.state == .running {
            l.state = .paused
            l.stopTimer()
        } else if l.state == .paused {
            l.state = .running
            l.startTimer { [weak self] ln in self?.tickLane(ln) }
        }
    }

    func addMoreTime(_ seconds: Int, lane: TaskGoLane? = nil) {
        let target = lane ?? lanes.first
        guard let l = target else { return }
        l.timeRemaining += seconds
        l.totalTime += seconds
        l.state = .running
        stopAlarm()
        l.startTimer { [weak self] ln in self?.tickLane(ln) }
    }

    func completeAndAdvance(lane: TaskGoLane? = nil) {
        let target = lane ?? lanes.first
        guard let l = target else { return }
        guard !l.isProcessingCompletion else { return }
        guard let task = l.currentTask else { return }

        l.isProcessingCompletion = true
        if let taskId = task.id { l.completedTaskIds.insert(taskId) }

        let minutes = l.elapsedSeconds / 60
        l.stopTimer()
        stopAlarm()

        Task {
            await xpVM?.awardXP(activeMinutes: minutes)

            if task.isChained {
                await taskVM?.markSingleComplete(task)
            } else {
                await taskVM?.markComplete(task)
            }

            let nextTask = resolveNextTask(for: l, after: task)
            l.isProcessingCompletion = false

            if let next = nextTask {
                advanceToNextTask(next, in: l)
            } else {
                removeLane(l)
            }
        }
    }

    // Legacy single-lane wrappers used by MainView
    func togglePause() { togglePause(lane: nil) }
    func addMoreTime(_ seconds: Int) { addMoreTime(seconds, lane: nil) }
    func completeAndAdvance() { completeAndAdvance(lane: nil) }

    func completeCurrentTask() -> (task: TaskItem, earnedXP: Int, activeMinutes: Int, activityPct: Double)? {
        guard let lane = lanes.first, let task = lane.currentTask else { return nil }
        let minutes = lane.elapsedSeconds / 60
        stopAlarm()
        var earnedXP = 0
        if activityMonitor.isMonitoring {
            let result = activityMonitor.stopMonitoring()
            earnedXP = activityMonitor.calculateEarnedXP(totalMinutes: minutes)
            _ = result
        }
        return (task: task, earnedXP: earnedXP, activeMinutes: minutes, activityPct: 0)
    }

    func advanceToNextTask(_ task: TaskItem) {
        guard let lane = lanes.first else { return }
        advanceToNextTask(task, in: lane)
    }

    func requestActivityPermission() {
        activityMonitor.requestPermission()
    }

    // MARK: - Internal

    private func advanceToNextTask(_ task: TaskItem, in lane: TaskGoLane) {
        var actualTask = task
        if let chainId = task.chainId, let firstStep = taskVM?.nextIncompleteChainStep(chainId) {
            actualTask = firstStep
        }
        lane.beginTask(actualTask)
        lane.startTimer { [weak self] l in self?.tickLane(l) }
    }

    private func resolveFirstTask(for lane: TaskGoLane) -> TaskItem? {
        let items = taskVM?.incompleteTasksForDisplay ?? []
        let inUse = allTaskIdsInUse
        let task = items.first { t in
            guard let id = t.id else { return false }
            if inUse.contains(id) && !lane.selectedTaskIds.contains(id) { return false }
            return lane.selectedTaskIds.contains(id)
        }
        if let t = task, let chainId = t.chainId {
            return taskVM?.nextIncompleteChainStep(chainId) ?? t
        }
        return task
    }

    private func resolveNextTask(for lane: TaskGoLane, after completedTask: TaskItem) -> TaskItem? {
        if let chainId = completedTask.chainId,
           let nextStep = taskVM?.nextIncompleteChainStep(chainId) {
            return nextStep
        }

        let items = taskVM?.incompleteTasksForDisplay ?? []
        let allUsed = allTaskIdsInUse
        let next = items.first { t in
            guard let id = t.id else { return false }
            if lane.completedTaskIds.contains(id) { return false }
            if allUsed.contains(id) && !lane.selectedTaskIds.contains(id) { return false }
            return lane.selectedTaskIds.contains(id)
        }
        if let n = next, let chainId = n.chainId {
            return taskVM?.nextIncompleteChainStep(chainId) ?? n
        }
        return next
    }

    // MARK: - Timer Tick

    private func tickLane(_ lane: TaskGoLane) {
        guard lane.state == .running else { return }
        lane.timeRemaining -= 1
        lane.elapsedSeconds += 1
        lane.elapsedActiveMinutes = lane.elapsedSeconds / 60
        if lane.timeRemaining <= 0 && lane.state == .running {
            laneExpired(lane)
        }
    }

    private func laneExpired(_ lane: TaskGoLane) {
        lane.state = .expired
        lane.stopTimer()
        playAlarm()
        triggerBounceAnimation()
    }

    // MARK: - Observe lane changes to propagate to parent

    private func observeLane(_ lane: TaskGoLane) {
        let c = lane.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        laneCancellables[lane.id] = c
    }

    // MARK: - Alarm

    private func playAlarm() {
        guard !isFocusModeActive() else { return }
        guard alarmPlayer == nil || !(alarmPlayer?.isPlaying ?? false) else { return }
        if let soundURL = Bundle.main.url(forResource: "gentle_chime", withExtension: "aiff") {
            alarmPlayer = NSSound(contentsOf: soundURL, byReference: true)
        } else {
            alarmPlayer = NSSound(named: "Glass")
        }
        alarmPlayer?.loops = true
        alarmPlayer?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.alarmPlayer?.loops = false
            self?.alarmPlayer?.stop()
        }
    }

    private func stopAlarm() {
        alarmPlayer?.loops = false
        alarmPlayer?.stop()
        alarmPlayer = nil
        NotificationCenter.default.post(name: .taskGoStopBounce, object: nil)
    }

    private func isFocusModeActive() -> Bool {
        _ = DistributedNotificationCenter.default()
        return false
    }

    private func triggerBounceAnimation() {
        NotificationCenter.default.post(name: .taskGoTimerExpired, object: nil)
    }

    // MARK: - Timer Panel

    private func showTimerPanel() {
        NotificationCenter.default.post(name: .taskGoShowPanel, object: nil)
    }

    private func hideTimerPanel() {
        NotificationCenter.default.post(name: .taskGoHidePanel, object: nil)
    }

    private func notifyPanelResize() {
        NotificationCenter.default.post(name: .taskGoPanelResize, object: lanes.count)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let taskGoTimerExpired = Notification.Name("taskGoTimerExpired")
    static let taskGoStopBounce = Notification.Name("taskGoStopBounce")
    static let taskGoShowPanel = Notification.Name("taskGoShowPanel")
    static let taskGoHidePanel = Notification.Name("taskGoHidePanel")
    static let taskGoPanelResize = Notification.Name("taskGoPanelResize")
}
