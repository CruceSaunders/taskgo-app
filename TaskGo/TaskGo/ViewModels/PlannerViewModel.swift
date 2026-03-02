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
    private var isSaving = false
    private var pendingSave: Plan?
    private var terminationObserver: NSObjectProtocol?
    private var isListening = false

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
        } else {
            Auth.auth().addStateDidChangeListener { [weak self] _, user in
                guard let self, let userId = user?.uid, !self.isListening else { return }
                Task { @MainActor in
                    self.beginListening(userId: userId)
                }
            }
        }
    }

    private func beginListening(userId: String) {
        guard !isListening else { return }
        isListening = true

        listener = firestoreService.listenToPlans(userId: userId) { [weak self] plans in
            Task { @MainActor in
                guard let self else { return }
                self.plans = plans
                if let selected = self.selectedPlan,
                   let updated = plans.first(where: { $0.id == selected.id }) {
                    self.selectedPlan = updated
                }
            }
        }

        if terminationObserver == nil {
            terminationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.flushSave()
            }
        }
    }

    func stopListening() {
        flushSave()
        listener?.remove()
        listener = nil
        isListening = false
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
        terminationObserver = nil
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

        var plan = Plan(
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
                plan.id = docId
                self.plans.insert(plan, at: 0)
                self.selectedPlan = plan
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
        Task {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            try? await firestoreService.deletePlan(planId, userId: userId)
        }
    }

    func completePlan() {
        guard selectedPlan != nil else { return }
        selectedPlan?.isComplete = true
        selectedPlan?.updatedAt = Date()
        save()
    }

    func reopenPlan() {
        guard selectedPlan != nil else { return }
        selectedPlan?.isComplete = false
        selectedPlan?.updatedAt = Date()
        save()
    }

    // MARK: - Objectives

    func addOverallObjective(text: String) {
        guard selectedPlan != nil, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let obj = PlanObjective(text: text.trimmingCharacters(in: .whitespaces))
        selectedPlan?.overallObjectives.append(obj)
        selectedPlan?.updatedAt = Date()
        save()
    }

    func addDailyObjective(date: String, text: String) {
        guard selectedPlan != nil, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let obj = PlanObjective(text: text.trimmingCharacters(in: .whitespaces))
        if selectedPlan?.dailyObjectives[date] == nil {
            selectedPlan?.dailyObjectives[date] = []
        }
        selectedPlan?.dailyObjectives[date]?.append(obj)
        selectedPlan?.updatedAt = Date()
        save()
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
        save()
    }

    func removeObjective(objectiveId: String, date: String?) {
        guard selectedPlan != nil else { return }
        if let date {
            selectedPlan?.dailyObjectives[date]?.removeAll { $0.id == objectiveId }
        } else {
            selectedPlan?.overallObjectives.removeAll { $0.id == objectiveId }
        }
        selectedPlan?.updatedAt = Date()
        save()
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
        save()
    }

    func updatePlanTitle(_ newTitle: String) {
        guard selectedPlan != nil, !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        selectedPlan?.title = newTitle.trimmingCharacters(in: .whitespaces)
        selectedPlan?.updatedAt = Date()
        save()
    }

    // MARK: - Save

    private func save() {
        guard let plan = selectedPlan else { return }

        if let idx = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[idx] = plan
        }

        Task {
            await persistPlan(plan)
        }
    }

    private func persistPlan(_ plan: Plan) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        do {
            try await firestoreService.savePlan(plan, userId: userId)
        } catch {
            print("[Planner] SAVE ERROR: \(error)")
        }
    }

    func flushSave() {
        guard let plan = selectedPlan else { return }
        if let idx = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[idx] = plan
        }
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            try? await FirestoreService.shared.savePlan(plan, userId: userId)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 3)
    }

    // MARK: - One-time data recovery

    func recoverPlan() {
        Task {
            var userId: String?
            for _ in 0..<20 {
                userId = Auth.auth().currentUser?.uid
                if userId != nil { break }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            guard let userId else {
                print("[Planner] RECOVERY: no user after 10s wait")
                return
            }
            await doRecover(userId: userId)
        }
    }

    private func doRecover(userId: String) async {
        let plan = Plan(
            title: "Session 4 Week 1",
            startDate: "2026-03-02",
            endDate: "2026-03-06",
            overallObjectives: [
                PlanObjective(text: "21 Carousel posts ready to post"),
                PlanObjective(text: "3 Fully warm TikTok accounts"),
                PlanObjective(text: "Monetized/Completed Ippo Update on the app store"),
                PlanObjective(text: "Have 21 carousels"),
            ],
            dailyObjectives: [
                "2026-03-02": [
                    PlanObjective(text: "Set up 3 TikTok Accounts"),
                    PlanObjective(text: "Warm Up TikTok accounts on metro"),
                    PlanObjective(text: "Add evolutions to Ippo"),
                    PlanObjective(text: "Debug/Test Ippo x3"),
                ],
                "2026-03-03": [
                    PlanObjective(text: "Debug/Test Ippo"),
                    PlanObjective(text: "Monetize Ippo"),
                    PlanObjective(text: "Warm up TikTok accounts on the Metro"),
                    PlanObjective(text: "Create 3 carousels"),
                    PlanObjective(text: "Insight/SPOV that I will defend"),
                ],
                "2026-03-04": [
                    PlanObjective(text: "Warm Up TikTok Accounts"),
                    PlanObjective(text: "Create 9 carousels"),
                ],
                "2026-03-05": [
                    PlanObjective(text: "Post one carousel on each TikTok account"),
                    PlanObjective(text: "Create 9 carousels"),
                ],
                "2026-03-06": [
                    PlanObjective(text: "Ensure: 3 solid themes, 21 carousels, complete app on the app store and monetized"),
                    PlanObjective(text: "Plan: how to automate carousel marketing? ClawdBot? Overseas Freelancer? How do we scale?"),
                    PlanObjective(text: "Plan: How can I get x3 committed beta testers?"),
                    PlanObjective(text: "Accountability Presentation"),
                ],
            ]
        )
        do {
            var saved = plan
            let docId = try await firestoreService.savePlan(plan, userId: userId)
            saved.id = docId
            self.plans.insert(saved, at: 0)
            self.selectedPlan = saved
            print("[Planner] RECOVERED plan successfully with id: \(docId)")
        } catch {
            print("[Planner] RECOVERY FAILED: \(error)")
        }
    }

    deinit {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
    }
}
