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
    private var saveTask: DispatchWorkItem?

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
        stopListening()
        guard let userId = Auth.auth().currentUser?.uid else { return }

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
    }

    func stopListening() {
        saveNow()
        listener?.remove()
        listener = nil
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
                try await firestoreService.savePlan(plan, userId: userId)
            } catch {
                print("[Planner] create error: \(error)")
            }
        }
    }

    func selectPlan(_ plan: Plan) {
        saveNow()
        selectedPlan = plan
    }

    func deletePlan(_ plan: Plan) {
        guard let planId = plan.id else { return }
        if selectedPlan?.id == planId { selectedPlan = nil }
        Task {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            try? await firestoreService.deletePlan(planId, userId: userId)
        }
    }

    func completePlan() {
        guard selectedPlan != nil else { return }
        selectedPlan?.isComplete = true
        selectedPlan?.updatedAt = Date()
        scheduleSave()
    }

    func reopenPlan() {
        guard selectedPlan != nil else { return }
        selectedPlan?.isComplete = false
        selectedPlan?.updatedAt = Date()
        scheduleSave()
    }

    // MARK: - Objectives

    func addOverallObjective(text: String) {
        guard selectedPlan != nil, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let obj = PlanObjective(text: text.trimmingCharacters(in: .whitespaces))
        selectedPlan?.overallObjectives.append(obj)
        selectedPlan?.updatedAt = Date()
        scheduleSave()
    }

    func addDailyObjective(date: String, text: String) {
        guard selectedPlan != nil, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let obj = PlanObjective(text: text.trimmingCharacters(in: .whitespaces))
        if selectedPlan?.dailyObjectives[date] == nil {
            selectedPlan?.dailyObjectives[date] = []
        }
        selectedPlan?.dailyObjectives[date]?.append(obj)
        selectedPlan?.updatedAt = Date()
        scheduleSave()
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
        scheduleSave()
    }

    func removeObjective(objectiveId: String, date: String?) {
        guard selectedPlan != nil else { return }
        if let date {
            selectedPlan?.dailyObjectives[date]?.removeAll { $0.id == objectiveId }
        } else {
            selectedPlan?.overallObjectives.removeAll { $0.id == objectiveId }
        }
        selectedPlan?.updatedAt = Date()
        scheduleSave()
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
        scheduleSave()
    }

    func updatePlanTitle(_ newTitle: String) {
        guard selectedPlan != nil, !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        selectedPlan?.title = newTitle.trimmingCharacters(in: .whitespaces)
        selectedPlan?.updatedAt = Date()
        scheduleSave()
    }

    // MARK: - Save

    private func scheduleSave() {
        saveTask?.cancel()
        guard let plan = selectedPlan else { return }

        // Optimistic local cache
        if let idx = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[idx] = plan
        }

        saveTask = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.save(plan)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: saveTask!)
    }

    func saveNow() {
        saveTask?.cancel()
        guard let plan = selectedPlan else { return }
        if let idx = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[idx] = plan
        }
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            guard let userId = Auth.auth().currentUser?.uid else {
                semaphore.signal()
                return
            }
            try? await FirestoreService.shared.savePlan(plan, userId: userId)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2)
    }

    private func save(_ plan: Plan) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        do {
            try await firestoreService.savePlan(plan, userId: userId)
            print("[Planner] saved plan \(plan.title)")
        } catch {
            print("[Planner] SAVE ERROR: \(error)")
        }
    }
}
