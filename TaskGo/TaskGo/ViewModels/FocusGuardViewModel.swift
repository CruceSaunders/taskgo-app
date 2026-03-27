import Foundation
import Combine

@MainActor
class FocusGuardViewModel: ObservableObject {
    @Published var selectedTask: TaskItem?
    @Published var contextText = ""
    @Published var showingSummary = false
    @Published var lastSummary: FocusSessionSummary?

    let service = FocusGuardService.shared
    private var cancellable: AnyCancellable?

    init() {
        cancellable = service.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.objectWillChange.send() }
        }
    }

    var isActive: Bool { service.isActive }

    func startFocus() {
        guard let task = selectedTask else { return }
        service.start(task: task, context: contextText)
    }

    func completeTask() -> TaskItem? {
        let task = service.currentTask
        let summary = service.completeTask()
        lastSummary = summary
        showingSummary = true
        selectedTask = nil
        contextText = ""
        return task
    }

    func stopWithoutCompleting() {
        let summary = service.stop()
        lastSummary = summary
        showingSummary = true
        selectedTask = nil
        contextText = ""
    }

    func snooze() {
        service.snooze(minutes: 5)
    }

    func updateContext() {
        service.updateContext(contextText)
    }

    func dismissSummary() {
        showingSummary = false
        lastSummary = nil
    }

    var timeFormatted: String {
        let total = service.timeElapsed
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
