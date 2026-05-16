import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class GoalViewModel: ObservableObject {
    @Published var goals: [Goal] = []
    @Published var selectedGoalId: String?
    @Published var errorMessage: String?

    /// Ticks every second while any non-completed stopwatch is running so views
    /// can re-render the displayed elapsed time. We don't save to Firestore on
    /// every tick — only on start / stop / explicit edits.
    @Published var stopwatchTick: Int = 0

    private var listener: ListenerRegistration?
    private var stopwatchTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    /// Local writes that haven't yet been round-tripped through the Firestore
    /// listener. While a goal id is in this set, listener snapshots for that
    /// goal are treated as advisory — we keep our optimistic local copy and
    /// only reconcile once it lands. Without this, rapid mutations (spam
    /// adding milestones, pause-while-running) lose updates to stale listener
    /// snapshots.
    private var pendingLocalWrites: Set<String> = []

    private var userId: String? { Auth.auth().currentUser?.uid }

    // MARK: - Lifecycle

    func startListening() {
        guard let userId = userId else { return }
        listener?.remove()
        listener = FirestoreService.shared.listenToGoals(userId: userId) { [weak self] goals in
            Task { @MainActor in
                guard let self = self else { return }
                self.mergeFromListener(goals)
                self.sanitizeCompletedGoals()
                self.refreshStopwatchTimer()
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        stopwatchTimer?.invalidate()
        stopwatchTimer = nil
        pendingLocalWrites.removeAll()
    }

    deinit {
        listener?.remove()
        stopwatchTimer?.invalidate()
    }

    // MARK: - Listener merge

    /// Replaces the local goal list with the listener payload but preserves
    /// any goals that have local writes still in flight. Without this, a user
    /// who spams `addMilestone` would see milestones disappear briefly as the
    /// listener delivers older snapshots.
    private func mergeFromListener(_ remoteGoals: [Goal]) {
        var byId: [String: Goal] = [:]
        for g in remoteGoals {
            if let id = g.id { byId[id] = g }
        }

        // Preserve locally-pending goals.
        for goal in goals {
            guard let id = goal.id, pendingLocalWrites.contains(id) else { continue }
            byId[id] = goal
        }

        // Preserve the previous server order, falling back to createdAt desc.
        let merged = byId.values.sorted { $0.createdAt > $1.createdAt }
        goals = merged
    }

    /// Defensive: a goal that was completed while the stopwatch was running
    /// in a prior buggy build could have a non-nil `stopwatchStartedAt`. Cap
    /// it: roll the time into totalElapsedSeconds and clear the runaway anchor.
    private func sanitizeCompletedGoals() {
        guard let userId = userId else { return }
        var dirty: [Goal] = []
        for i in 0..<goals.count {
            guard goals[i].isCompleted, goals[i].isStopwatchRunning,
                  let started = goals[i].stopwatchStartedAt else { continue }
            let delta = max(0, Int(Date().timeIntervalSince(started)))
            goals[i].totalElapsedSeconds += delta
            goals[i].stopwatchStartedAt = nil
            goals[i].updatedAt = Date()
            dirty.append(goals[i])
        }
        guard !dirty.isEmpty else { return }
        for goal in dirty {
            guard let id = goal.id else { continue }
            pendingLocalWrites.insert(id)
            Task {
                do {
                    _ = try await FirestoreService.shared.saveGoal(goal, userId: userId)
                } catch {
                    print("[GoalVM] sanitize save failed: \(error)")
                }
                _ = await MainActor.run { self.pendingLocalWrites.remove(id) }
            }
        }
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
        mutate(goal) { $0.title = trimmed }
    }

    func updateNotes(_ goal: Goal, notes: String) {
        mutate(goal) { $0.notes = notes }
    }

    func updateTimeline(_ goal: Goal, startDate: Date, estimatedEndDate: Date?) {
        mutate(goal) {
            $0.startDate = startDate
            $0.estimatedEndDate = estimatedEndDate
        }
    }

    func deleteGoal(_ goal: Goal) {
        guard let userId = userId, let goalId = goal.id else { return }
        if selectedGoalId == goalId { selectedGoalId = nil }
        // Optimistic local remove
        goals.removeAll { $0.id == goalId }
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
        mutate(goal) { g in
            // Roll any in-flight stopwatch time into the total before freezing.
            if g.isStopwatchRunning, let started = g.stopwatchStartedAt {
                let delta = max(0, Int(Date().timeIntervalSince(started)))
                g.totalElapsedSeconds += delta
                g.stopwatchStartedAt = nil
            }
            g.completedAt = Date()
        }
        refreshStopwatchTimer()
    }

    func reopenGoal(_ goal: Goal) {
        mutate(goal) { $0.completedAt = nil }
    }

    // MARK: - Milestones

    func addMilestone(_ goal: Goal, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate(goal) { g in
            let nextPos = (g.milestones.map(\.position).max() ?? -1) + 1
            g.milestones.append(Milestone(title: trimmed, position: nextPos))
        }
    }

    func renameMilestone(_ goal: Goal, milestoneId: String, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate(goal) { g in
            guard let idx = g.milestones.firstIndex(where: { $0.id == milestoneId }) else { return }
            g.milestones[idx].title = trimmed
        }
    }

    func toggleMilestoneComplete(_ goal: Goal, milestoneId: String) {
        mutate(goal) { g in
            guard let idx = g.milestones.firstIndex(where: { $0.id == milestoneId }) else { return }
            let nowComplete = !g.milestones[idx].isComplete
            g.milestones[idx].isComplete = nowComplete
            g.milestones[idx].completedAt = nowComplete ? Date() : nil
        }
    }

    func deleteMilestone(_ goal: Goal, milestoneId: String) {
        mutate(goal) { g in
            g.milestones.removeAll { $0.id == milestoneId }
            for i in 0..<g.milestones.count {
                g.milestones[i].position = i
            }
        }
    }

    func moveMilestone(_ goal: Goal, from source: IndexSet, to destination: Int) {
        mutate(goal) { g in
            var sorted = g.milestones.sorted { $0.position < $1.position }
            sorted.move(fromOffsets: source, toOffset: destination)
            for i in 0..<sorted.count {
                sorted[i].position = i
            }
            g.milestones = sorted
        }
    }

    // MARK: - Stopwatch

    func startStopwatch(_ goal: Goal) {
        guard !goal.isCompleted else { return }
        // Stop any other goal's stopwatch first so only one runs at a time.
        // We resolve fresh local copies (rather than holding stale closures)
        // by id so we don't fight ourselves through old snapshots.
        let otherRunningIds: [String] = goals
            .filter { $0.id != goal.id && $0.isStopwatchRunning }
            .compactMap { $0.id }
        for otherId in otherRunningIds {
            if let other = goals.first(where: { $0.id == otherId }) {
                stopStopwatchInternal(other)
            }
        }

        guard let id = goal.id, let idx = goals.firstIndex(where: { $0.id == id }) else { return }
        guard !goals[idx].isStopwatchRunning else { return }
        var updated = goals[idx]
        updated.stopwatchStartedAt = Date()
        updated.updatedAt = Date()
        goals[idx] = updated
        persistOptimistic(updated)
        refreshStopwatchTimer()
    }

    func stopStopwatch(_ goal: Goal) {
        stopStopwatchInternal(goal)
        refreshStopwatchTimer()
    }

    private func stopStopwatchInternal(_ goal: Goal) {
        guard let id = goal.id, let idx = goals.firstIndex(where: { $0.id == id }) else { return }
        guard let started = goals[idx].stopwatchStartedAt else { return }
        let delta = max(0, Int(Date().timeIntervalSince(started)))
        var updated = goals[idx]
        updated.totalElapsedSeconds += delta
        updated.stopwatchStartedAt = nil
        updated.updatedAt = Date()
        goals[idx] = updated
        persistOptimistic(updated)
    }

    func toggleStopwatch(_ goal: Goal) {
        // Resolve the freshest local copy by id rather than trusting the
        // possibly-stale closure-captured `goal`.
        let current: Goal
        if let id = goal.id, let live = goals.first(where: { $0.id == id }) {
            current = live
        } else {
            current = goal
        }
        if current.isStopwatchRunning {
            stopStopwatch(current)
        } else {
            startStopwatch(current)
        }
    }

    func setManualElapsed(_ goal: Goal, seconds: Int) {
        mutate(goal) { g in
            g.totalElapsedSeconds = max(0, seconds)
            // If currently running, reset the start anchor so the live timer
            // continues counting from the new total.
            if g.isStopwatchRunning {
                g.stopwatchStartedAt = Date()
            }
        }
    }

    /// Returns the live elapsed seconds for a goal, including any in-flight
    /// stopwatch. For completed goals the value is always frozen regardless
    /// of any (defensively unexpected) startedAt.
    func liveElapsedSeconds(_ goal: Goal) -> Int {
        if goal.isCompleted { return goal.totalElapsedSeconds }
        return goal.liveElapsedSeconds()
    }

    private func refreshStopwatchTimer() {
        let anyRunning = goals.contains { !$0.isCompleted && $0.isStopwatchRunning }
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

    // MARK: - Optimistic mutation

    /// Mutates a goal in the local `goals` array atomically and kicks off
    /// the Firestore save in the background. The local mutation happens
    /// synchronously so the UI updates immediately and subsequent calls
    /// see the latest state — critical for rapid-fire actions like
    /// spam-adding milestones or rapid pause/resume.
    private func mutate(_ goal: Goal, _ block: (inout Goal) -> Void) {
        guard let id = goal.id, let idx = goals.firstIndex(where: { $0.id == id }) else { return }
        var updated = goals[idx]
        block(&updated)
        updated.updatedAt = Date()
        goals[idx] = updated
        persistOptimistic(updated)
    }

    private func persistOptimistic(_ goal: Goal) {
        guard let userId = userId, let id = goal.id else { return }
        pendingLocalWrites.insert(id)
        Task {
            do {
                _ = try await FirestoreService.shared.saveGoal(goal, userId: userId)
            } catch {
                self.errorMessage = "Couldn't save goal: \(error.localizedDescription)"
            }
            _ = await MainActor.run { self.pendingLocalWrites.remove(id) }
        }
    }
}
