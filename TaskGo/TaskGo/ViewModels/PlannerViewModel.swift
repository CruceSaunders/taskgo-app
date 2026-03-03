import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

enum PlanFilter: String, CaseIterable {
    case active = "Active"
    case completed = "Done"
    case all = "All"
}

@MainActor
class PlannerViewModel: ObservableObject {
    @Published var plans: [Plan] = []
    @Published var selectedPlan: Plan?
    @Published var showCreatePlan = false
    @Published var filter: PlanFilter = .active

    private let firestoreService = FirestoreService.shared
    private var listener: ListenerRegistration?
    private var terminationObserver: NSObjectProtocol?
    private var authListener: AuthStateDidChangeListenerHandle?
    private var isListening = false

    /// Tracks IDs of plans with local edits not yet confirmed by the listener.
    /// When the listener fires, plans in this set keep their LOCAL version
    /// instead of being overwritten by potentially stale Firestore data.
    private var dirtyPlanIds = Set<String>()

    /// Prevents listener overwrites during the brief window between
    /// createPlan saving to Firestore and the listener echoing it back.
    private var recentlyCreatedIds = Set<String>()

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self, let userId = user?.uid else { return }
            Task { @MainActor in
                self.beginListening(userId: userId)
            }
        }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flushSave()
        }
    }

    var filteredPlans: [Plan] {
        let filtered: [Plan]
        switch filter {
        case .active:
            filtered = plans.filter { !$0.isComplete }
        case .completed:
            filtered = plans.filter { $0.isComplete }
        case .all:
            filtered = plans
        }
        return filtered.sorted { a, b in
            if a.isComplete != b.isComplete { return !a.isComplete }
            if !a.isComplete {
                return a.startDate < b.startDate
            }
            return a.updatedAt > b.updatedAt
        }
    }

    // MARK: - Listening

    func startListening() {
        guard !isListening else { return }
        if let userId = Auth.auth().currentUser?.uid {
            beginListening(userId: userId)
        }
    }

    private func beginListening(userId: String) {
        guard !isListening else { return }
        isListening = true
        print("[Planner] beginListening for userId=\(userId)")

        listener = firestoreService.listenToPlans(userId: userId) { [weak self] incomingPlans in
            Task { @MainActor in
                guard let self else { return }
                print("[Planner] listener received \(incomingPlans.count) plans")

                // Merge: keep local versions for plans we've edited but haven't
                // had confirmed by a round-trip yet.
                var merged = incomingPlans
                for dirtyId in self.dirtyPlanIds {
                    if let localPlan = self.plans.first(where: { $0.id == dirtyId }) {
                        if let idx = merged.firstIndex(where: { $0.id == dirtyId }) {
                            // Only keep local if our updatedAt is newer
                            if localPlan.updatedAt >= merged[idx].updatedAt {
                                merged[idx] = localPlan
                            } else {
                                // Server has newer data (confirmed our write), clear dirty
                                self.dirtyPlanIds.remove(dirtyId)
                            }
                        }
                    } else {
                        self.dirtyPlanIds.remove(dirtyId)
                    }
                }

                self.plans = merged

                // Update selectedPlan, but respect dirty state
                if let selected = self.selectedPlan,
                   let selectedId = selected.id {
                    if self.dirtyPlanIds.contains(selectedId) {
                        // Don't overwrite -- we have local edits pending
                    } else if let updated = merged.first(where: { $0.id == selectedId }) {
                        self.selectedPlan = updated
                    }
                }
            }
        }
    }

    func stopListening() {
        flushSave()
        listener?.remove()
        listener = nil
        isListening = false
    }

    // MARK: - Plan CRUD

    func createPlan(title: String, startDate: Date, endDate: Date) {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        var dailyObjectives: [String: [PlanObjective]] = [:]
        var current = startDate
        while current <= endDate {
            dailyObjectives[fmt.string(from: current)] = []
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        let plan = Plan(
            title: title,
            startDate: fmt.string(from: startDate),
            endDate: fmt.string(from: endDate),
            overallObjectives: [],
            dailyObjectives: dailyObjectives
        )

        Task {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            do {
                let docId = try await firestoreService.savePlan(plan, userId: userId)
                var savedPlan = plan
                savedPlan.id = docId
                self.recentlyCreatedIds.insert(docId)
                self.plans.insert(savedPlan, at: 0)
                self.selectedPlan = savedPlan
                print("[Planner] created plan '\(title)' with id=\(docId)")

                // Clear the recently-created flag after the listener has had time to echo
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self.recentlyCreatedIds.remove(docId)
            } catch {
                print("[Planner] create error: \(error)")
            }
        }
    }

    func selectPlan(_ plan: Plan) {
        flushSave()
        selectedPlan = plan
    }

    func deletePlan(_ plan: Plan) {
        guard let planId = plan.id else { return }
        if selectedPlan?.id == planId { selectedPlan = nil }
        plans.removeAll { $0.id == planId }
        dirtyPlanIds.remove(planId)
        Task {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            try? await firestoreService.deletePlan(planId, userId: userId)
        }
    }

    func completePlan() {
        guard selectedPlan != nil else { return }
        selectedPlan?.isComplete = true
        selectedPlan?.updatedAt = Date()
        markDirtyAndSave()
    }

    func reopenPlan() {
        guard selectedPlan != nil else { return }
        selectedPlan?.isComplete = false
        selectedPlan?.updatedAt = Date()
        markDirtyAndSave()
    }

    // MARK: - Objectives

    func addOverallObjective(text: String) {
        guard selectedPlan != nil, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let obj = PlanObjective(text: text.trimmingCharacters(in: .whitespaces))
        selectedPlan?.overallObjectives.append(obj)
        selectedPlan?.updatedAt = Date()
        markDirtyAndSave()
    }

    func addDailyObjective(date: String, text: String) {
        guard selectedPlan != nil, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let obj = PlanObjective(text: text.trimmingCharacters(in: .whitespaces))
        if selectedPlan?.dailyObjectives[date] == nil {
            selectedPlan?.dailyObjectives[date] = []
        }
        selectedPlan?.dailyObjectives[date]?.append(obj)
        selectedPlan?.updatedAt = Date()
        markDirtyAndSave()
    }

    func toggleObjective(objectiveId: String, date: String?) {
        guard selectedPlan != nil else { return }
        if let date {
            if let idx = selectedPlan?.dailyObjectives[date]?.firstIndex(where: { $0.id == objectiveId }) {
                selectedPlan?.dailyObjectives[date]?[idx].isComplete.toggle()
            }
        } else {
            if let idx = selectedPlan?.overallObjectives.firstIndex(where: { $0.id == objectiveId }) {
                selectedPlan?.overallObjectives[idx].isComplete.toggle()
            }
        }
        selectedPlan?.updatedAt = Date()
        markDirtyAndSave()
    }

    func removeObjective(objectiveId: String, date: String?) {
        guard selectedPlan != nil else { return }
        if let date {
            selectedPlan?.dailyObjectives[date]?.removeAll { $0.id == objectiveId }
        } else {
            selectedPlan?.overallObjectives.removeAll { $0.id == objectiveId }
        }
        selectedPlan?.updatedAt = Date()
        markDirtyAndSave()
    }

    func updateObjectiveText(objectiveId: String, date: String?, newText: String) {
        guard selectedPlan != nil, !newText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if let date {
            if let idx = selectedPlan?.dailyObjectives[date]?.firstIndex(where: { $0.id == objectiveId }) {
                selectedPlan?.dailyObjectives[date]?[idx].text = newText.trimmingCharacters(in: .whitespaces)
            }
        } else {
            if let idx = selectedPlan?.overallObjectives.firstIndex(where: { $0.id == objectiveId }) {
                selectedPlan?.overallObjectives[idx].text = newText.trimmingCharacters(in: .whitespaces)
            }
        }
        selectedPlan?.updatedAt = Date()
        markDirtyAndSave()
    }

    func updatePlanTitle(_ newTitle: String) {
        guard selectedPlan != nil, !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        selectedPlan?.title = newTitle.trimmingCharacters(in: .whitespaces)
        selectedPlan?.updatedAt = Date()
        markDirtyAndSave()
    }

    // MARK: - Save

    /// Marks the selected plan as dirty (protecting it from listener overwrites)
    /// and immediately persists it to Firestore.
    private func markDirtyAndSave() {
        guard let plan = selectedPlan, let planId = plan.id else { return }

        dirtyPlanIds.insert(planId)

        if let idx = plans.firstIndex(where: { $0.id == planId }) {
            plans[idx] = plan
        }

        Task {
            await persistPlan(plan)
            // After successful persist, the listener will eventually echo back
            // the confirmed data. We clear dirty after a delay to let that happen.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.dirtyPlanIds.remove(planId)
        }
    }

    private func persistPlan(_ plan: Plan) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[Planner] save skipped: no authenticated user")
            return
        }
        do {
            try await firestoreService.savePlan(plan, userId: userId)
            print("[Planner] saved plan '\(plan.title)' (\(plan.totalObjectives) objectives)")
        } catch {
            print("[Planner] SAVE ERROR: \(error)")
        }
    }

    func flushSave() {
        guard let plan = selectedPlan, plan.id != nil else { return }
        if let idx = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[idx] = plan
        }
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                try await FirestoreService.shared.savePlan(plan, userId: userId)
                print("[Planner] flushSave completed for '\(plan.title)'")
            } catch {
                print("[Planner] flushSave ERROR: \(error)")
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 3)
    }

    deinit {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
        if let authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
    }
}
