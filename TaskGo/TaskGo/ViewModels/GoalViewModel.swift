import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class GoalViewModel: ObservableObject {
    @Published var goals: [Goal] = []
    @Published var selectedGoalId: String?
    @Published var errorMessage: String?

    /// Ticks every second while any stopwatch is running so views can re-render
    /// the displayed elapsed time. We don't save to Firestore on every tick —
    /// only on start / stop / explicit edits.
    @Published var stopwatchTick: Int = 0

    private var listener: ListenerRegistration?
    private var stopwatchTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? { Auth.auth().currentUser?.uid }

    // MARK: - Lifecycle

    func startListening() {
        guard let userId = userId else { return }
        listener?.remove()
        listener = FirestoreService.shared.listenToGoals(userId: userId) { [weak self] goals in
            Task { @MainActor in
                guard let self = self else { return }
                self.goals = goals
                self.refreshStopwatchTimer()
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        stopwatchTimer?.invalidate()
        stopwatchTimer = nil
    }

    deinit {
        listener?.remove()
        stopwatchTimer?.invalidate()
    }

    // MARK: - Selection helpers

    var selectedGoal: Goal? {
        guard let id = selectedGoalId else { return nil }
        return goals.first { $0.id == id }
    }

    var activeGoals: [Goal] {
        goals.filter { !$0.isCompleted }
    }

    var completedGoals: [Goal] {
        goals.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    // MARK: - CRUD

    func createGoal(title: String, startDate: Date = Date(), estimatedEndDate: Date? = nil) {
        guard let userId = userId else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let goal = Goal(
            title: trimmed,
            startDate: startDate,
            estimatedEndDate: estimatedEndDate
        )
        Task {
            do {
                let newId = try await FirestoreService.shared.saveGoal(goal, userId: userId)
                await MainActor.run { self.selectedGoalId = newId }
            } catch {
                self.errorMessage = "Couldn't create goal: \(error.localizedDescription)"
            }
        }
    }

    func renameGoal(_ goal: Goal, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = goal
        updated.title = trimmed
        updated.updatedAt = Date()
        save(updated)
    }

    func updateNotes(_ goal: Goal, notes: String) {
        var updated = goal
        updated.notes = notes
        updated.updatedAt = Date()
        save(updated)
    }

    func updateTimeline(_ goal: Goal, startDate: Date, estimatedEndDate: Date?) {
        var updated = goal
        updated.startDate = startDate
        updated.estimatedEndDate = estimatedEndDate
        updated.updatedAt = Date()
        save(updated)
    }

    func deleteGoal(_ goal: Goal) {
        guard let userId = userId, let goalId = goal.id else { return }
        if selectedGoalId == goalId { selectedGoalId = nil }
        Task {
            do {
                try await FirestoreService.shared.deleteGoal(goalId, userId: userId)
            } catch {
                self.errorMessage = "Couldn't delete goal: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Completion

    func markGoalComplete(_ goal: Goal) {
        var updated = goal
        // Implicitly stop the stopwatch if it was running so we capture all the time.
        if updated.isStopwatchRunning, let started = updated.stopwatchStartedAt {
            let delta = max(0, Int(Date().timeIntervalSince(started)))
            updated.totalElapsedSeconds += delta
            updated.stopwatchStartedAt = nil
        }
        updated.completedAt = Date()
        updated.updatedAt = Date()
        save(updated)
    }

    func reopenGoal(_ goal: Goal) {
        var updated = goal
        updated.completedAt = nil
        updated.updatedAt = Date()
        save(updated)
    }

    // MARK: - Milestones

    func addMilestone(_ goal: Goal, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = goal
        let nextPos = (updated.milestones.map(\.position).max() ?? -1) + 1
        let milestone = Milestone(title: trimmed, position: nextPos)
        updated.milestones.append(milestone)
        updated.updatedAt = Date()
        save(updated)
    }

    func renameMilestone(_ goal: Goal, milestoneId: String, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = goal
        guard let idx = updated.milestones.firstIndex(where: { $0.id == milestoneId }) else { return }
        updated.milestones[idx].title = trimmed
        updated.updatedAt = Date()
        save(updated)
    }

    func toggleMilestoneComplete(_ goal: Goal, milestoneId: String) {
        var updated = goal
        guard let idx = updated.milestones.firstIndex(where: { $0.id == milestoneId }) else { return }
        let nowComplete = !updated.milestones[idx].isComplete
        updated.milestones[idx].isComplete = nowComplete
        updated.milestones[idx].completedAt = nowComplete ? Date() : nil
        updated.updatedAt = Date()
        save(updated)
    }

    func deleteMilestone(_ goal: Goal, milestoneId: String) {
        var updated = goal
        updated.milestones.removeAll { $0.id == milestoneId }
        // Re-pack positions
        for i in 0..<updated.milestones.count {
            updated.milestones[i].position = i
        }
        updated.updatedAt = Date()
        save(updated)
    }

    func moveMilestone(_ goal: Goal, from source: IndexSet, to destination: Int) {
        var updated = goal
        var sorted = updated.milestones.sorted { $0.position < $1.position }
        sorted.move(fromOffsets: source, toOffset: destination)
        for i in 0..<sorted.count {
            sorted[i].position = i
        }
        updated.milestones = sorted
        updated.updatedAt = Date()
        save(updated)
    }

    // MARK: - Stopwatch

    func startStopwatch(_ goal: Goal) {
        // Stop any other goal's stopwatch first so only one runs at a time.
        for g in goals where g.id != goal.id && g.isStopwatchRunning {
            stopStopwatch(g)
        }
        var updated = goal
        guard !updated.isStopwatchRunning else { return }
        updated.stopwatchStartedAt = Date()
        updated.updatedAt = Date()
        save(updated)
        refreshStopwatchTimer()
    }

    func stopStopwatch(_ goal: Goal) {
        var updated = goal
        guard let started = updated.stopwatchStartedAt else { return }
        let delta = max(0, Int(Date().timeIntervalSince(started)))
        updated.totalElapsedSeconds += delta
        updated.stopwatchStartedAt = nil
        updated.updatedAt = Date()
        save(updated)
        refreshStopwatchTimer()
    }

    func toggleStopwatch(_ goal: Goal) {
        if goal.isStopwatchRunning {
            stopStopwatch(goal)
        } else {
            startStopwatch(goal)
        }
    }

    func setManualElapsed(_ goal: Goal, seconds: Int) {
        var updated = goal
        updated.totalElapsedSeconds = max(0, seconds)
        // If currently running, reset the start anchor so the live timer
        // continues counting from the new total.
        if updated.isStopwatchRunning {
            updated.stopwatchStartedAt = Date()
        }
        updated.updatedAt = Date()
        save(updated)
    }

    /// Returns the live elapsed seconds for a goal, including any in-flight stopwatch.
    func liveElapsedSeconds(_ goal: Goal) -> Int {
        return goal.liveElapsedSeconds()
    }

    private func refreshStopwatchTimer() {
        let anyRunning = goals.contains { $0.isStopwatchRunning }
        if anyRunning && stopwatchTimer == nil {
            let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.stopwatchTick &+= 1 }
            }
            RunLoop.main.add(t, forMode: .common)
            stopwatchTimer = t
        } else if !anyRunning && stopwatchTimer != nil {
            stopwatchTimer?.invalidate()
            stopwatchTimer = nil
        }
    }

    // MARK: - Save

    private func save(_ goal: Goal) {
        guard let userId = userId else { return }
        Task {
            do {
                _ = try await FirestoreService.shared.saveGoal(goal, userId: userId)
            } catch {
                self.errorMessage = "Couldn't save goal: \(error.localizedDescription)"
            }
        }
    }
}
