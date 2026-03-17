import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

enum PlanFilter: String, CaseIterable {
    case active = "Active"
    case completed = "Done"
    case all = "All"
}

enum ConversionState: Equatable {
    case idle
    case validating
    case scheduling
    case creatingEvents
    case success(Int)
    case error(ConversionError)
}

enum ConversionError: Equatable {
    case noScheduleConfig
    case noCalendarAccess
    case missingDurations(count: Int, daysMissing: [String])
    case dayOverflow(details: [DayOverflowDetail])
    case nothingToConvert
    case alreadyConverted(Date)
    case aiError(String)
    case calendarWriteError(String)
}

struct DayOverflowDetail: Equatable {
    let date: String
    let neededMinutes: Int
    let availableMinutes: Int
}

@MainActor
class PlannerViewModel: ObservableObject {
    @Published var plans: [Plan] = []
    @Published var selectedPlan: Plan?
    @Published var showCreatePlan = false
    @Published var filter: PlanFilter = .active
    @Published var conversionState: ConversionState = .idle

    private let firestoreService = FirestoreService.shared
    private let calendarService = CalendarService.shared
    private let aiScheduler = AISchedulerService.shared
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
            self?.syncSaveOnExit()
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

    func reorderObjective(date: String, fromIndex: Int, toIndex: Int) {
        guard selectedPlan != nil,
              var objs = selectedPlan?.dailyObjectives[date],
              fromIndex >= 0, fromIndex < objs.count,
              toIndex >= 0, toIndex < objs.count,
              fromIndex != toIndex else { return }
        let item = objs.remove(at: fromIndex)
        objs.insert(item, at: toIndex)
        selectedPlan?.dailyObjectives[date] = objs
        selectedPlan?.updatedAt = Date()
        markDirtyAndSave()
    }

    func moveObjectiveBetweenDays(objectiveId: String, fromDate: String, toDate: String) {
        guard selectedPlan != nil,
              fromDate != toDate,
              let fromIdx = selectedPlan?.dailyObjectives[fromDate]?.firstIndex(where: { $0.id == objectiveId })
        else { return }
        let obj = selectedPlan!.dailyObjectives[fromDate]![fromIdx]
        selectedPlan?.dailyObjectives[fromDate]?.remove(at: fromIdx)
        if selectedPlan?.dailyObjectives[toDate] == nil {
            selectedPlan?.dailyObjectives[toDate] = []
        }
        selectedPlan?.dailyObjectives[toDate]?.append(obj)
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
        Task {
            await persistPlan(plan)
        }
    }

    private func syncSaveOnExit() {
        guard let plan = selectedPlan, plan.id != nil else { return }
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            try? await FirestoreService.shared.savePlan(plan, userId: userId)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2)
    }

    // MARK: - Per-Plan Schedule Config

    func updateScheduleTimes(start: String, end: String) {
        guard selectedPlan != nil else { return }
        selectedPlan?.scheduleStartTime = start
        selectedPlan?.scheduleEndTime = end
        selectedPlan?.updatedAt = Date()
        markDirtyAndSave()
    }

    func updateCalendarId(_ calendarId: String) {
        guard selectedPlan != nil else { return }
        selectedPlan?.calendarId = calendarId
        selectedPlan?.updatedAt = Date()
        markDirtyAndSave()
    }

    func updateBreakConfig(enabled: Bool, minutes: Int, count: Int) {
        guard selectedPlan != nil else { return }
        selectedPlan?.breakEnabled = enabled
        selectedPlan?.breakMinutes = minutes
        selectedPlan?.breakCount = count
        selectedPlan?.updatedAt = Date()
        markDirtyAndSave()
    }

    // MARK: - Duration Management

    func updateObjectiveDuration(objectiveId: String, date: String?, minutes: Int?) {
        guard selectedPlan != nil else { return }
        if let date {
            if let idx = selectedPlan?.dailyObjectives[date]?.firstIndex(where: { $0.id == objectiveId }) {
                selectedPlan?.dailyObjectives[date]?[idx].estimatedMinutes = minutes
            }
        } else {
            if let idx = selectedPlan?.overallObjectives.firstIndex(where: { $0.id == objectiveId }) {
                selectedPlan?.overallObjectives[idx].estimatedMinutes = minutes
            }
        }
        selectedPlan?.updatedAt = Date()
        markDirtyAndSave()
    }

    // MARK: - Convert to Calendar

    func convertToCalendar(forceReconvert: Bool = false) {
        guard let plan = selectedPlan, !plan.isComplete else { return }

        Task {
            conversionState = .validating

            if !forceReconvert, let lastConverted = plan.lastConvertedAt {
                conversionState = .error(.alreadyConverted(lastConverted))
                return
            }

            guard let startTime = plan.scheduleStartTime,
                  let endTime = plan.scheduleEndTime,
                  let calId = plan.calendarId else {
                conversionState = .error(.noScheduleConfig)
                return
            }

            guard calendarService.hasAccess else {
                conversionState = .error(.noCalendarAccess)
                return
            }

            let activeDays = plan.dateRange.filter { dateStr in
                let objectives = plan.dailyObjectives[dateStr] ?? []
                return objectives.contains { !$0.isComplete }
            }

            guard !activeDays.isEmpty else {
                conversionState = .error(.nothingToConvert)
                return
            }

            let daysMissing = plan.daysWithMissingDurations().filter { activeDays.contains($0) }
            if !daysMissing.isEmpty {
                let count = daysMissing.reduce(0) { total, dateStr in
                    total + (plan.dailyObjectives[dateStr] ?? []).filter { !$0.isComplete && ($0.estimatedMinutes ?? 0) == 0 }.count
                }
                conversionState = .error(.missingDurations(count: count, daysMissing: daysMissing))
                return
            }

            var overflowDetails: [DayOverflowDetail] = []
            for dateStr in activeDays {
                let taskMinutes = plan.totalMinutesForDay(dateStr)
                let breakMinutesForDay = plan.totalBreakMinutesForDay(dateStr)
                let neededMinutes = taskMinutes + breakMinutesForDay
                guard neededMinutes > 0 else { continue }
                guard let date = Plan.dateFmt.date(from: dateStr) else { continue }

                let existingEvents = calendarService.fetchEvents(for: date, startTime: startTime, endTime: endTime)
                let busyMinutes = existingEvents.reduce(0) { $0 + Int(max(0, $1.endDate.timeIntervalSince($1.startDate) / 60)) }
                let availableMinutes = plan.scheduleMinutesPerDay - busyMinutes

                if neededMinutes > availableMinutes {
                    overflowDetails.append(DayOverflowDetail(date: dateStr, neededMinutes: neededMinutes, availableMinutes: max(0, availableMinutes)))
                }
            }

            if !overflowDetails.isEmpty {
                conversionState = .error(.dayOverflow(details: overflowDetails))
                return
            }

            // Delete old events if reconverting
            if forceReconvert, let oldIds = plan.createdEventIds {
                for eventId in oldIds {
                    try? calendarService.deleteEvent(identifier: eventId)
                }
                selectedPlan?.createdEventIds = nil
            }

            conversionState = .scheduling
            var allScheduledBlocks: [(date: Date, blocks: [ScheduledBlock])] = []

            for dateStr in activeDays {
                let objectives = (plan.dailyObjectives[dateStr] ?? []).filter { !$0.isComplete }
                guard !objectives.isEmpty else { continue }
                guard let date = Plan.dateFmt.date(from: dateStr) else { continue }

                let taskInputs = objectives.map { obj in
                    ScheduleTaskInput(objectiveId: obj.id, title: obj.text, durationMinutes: obj.estimatedMinutes ?? 30)
                }

                let dayBreakCount = plan.effectiveBreakCountForDay(dateStr)
                let dayBreakMinutes = plan.breakMinutes ?? 10

                let existingEvents = calendarService.fetchEvents(for: date, startTime: startTime, endTime: endTime)
                let timeFmt = DateFormatter()
                timeFmt.dateFormat = "HH:mm"
                let existingInputs = existingEvents.map { event in
                    ExistingEventInput(title: event.title, startTime: timeFmt.string(from: event.startDate), endTime: timeFmt.string(from: event.endDate))
                }

                do {
                    let blocks = try await aiScheduler.generateSchedule(
                        tasks: taskInputs, existingEvents: existingInputs,
                        officeHoursStart: startTime, officeHoursEnd: endTime,
                        dateLabel: Plan.displayDayLabel(for: dateStr),
                        breakCount: dayBreakCount, breakMinutes: dayBreakMinutes
                    )
                    allScheduledBlocks.append((date: date, blocks: blocks))
                } catch {
                    print("[Planner] AI scheduling failed for \(dateStr): \(error). Using fallback.")
                    let fallbackBlocks = aiScheduler.sequentialFallback(
                        tasks: taskInputs, existingEvents: existingInputs,
                        officeHoursStart: startTime, officeHoursEnd: endTime,
                        breakCount: dayBreakCount, breakMinutes: dayBreakMinutes
                    )
                    allScheduledBlocks.append((date: date, blocks: fallbackBlocks))
                }
            }

            conversionState = .creatingEvents
            var totalCreated = 0
            var newEventIds: [String] = []
            let cal = Calendar.current
            let timeFmt = DateFormatter()
            timeFmt.dateFormat = "HH:mm"

            for (date, blocks) in allScheduledBlocks {
                let startOfDay = cal.startOfDay(for: date)
                for block in blocks {
                    guard let startParsed = timeFmt.date(from: block.startTime),
                          let endParsed = timeFmt.date(from: block.endTime) else { continue }
                    let startComps = cal.dateComponents([.hour, .minute], from: startParsed)
                    let endComps = cal.dateComponents([.hour, .minute], from: endParsed)
                    guard let eventStart = cal.date(bySettingHour: startComps.hour ?? 0, minute: startComps.minute ?? 0, second: 0, of: startOfDay),
                          let eventEnd = cal.date(bySettingHour: endComps.hour ?? 0, minute: endComps.minute ?? 0, second: 0, of: startOfDay) else { continue }

                    do {
                        let eventId = try calendarService.createEvent(title: block.title, startDate: eventStart, endDate: eventEnd, calendarIdentifier: calId)
                        newEventIds.append(eventId)
                        totalCreated += 1
                    } catch {
                        print("[Planner] Failed to create event '\(block.title)': \(error)")
                        conversionState = .error(.calendarWriteError(error.localizedDescription))
                        return
                    }
                }
            }

            selectedPlan?.createdEventIds = newEventIds
            selectedPlan?.lastConvertedAt = Date()
            selectedPlan?.updatedAt = Date()
            markDirtyAndSave()

            conversionState = .success(totalCreated)
        }
    }

    func removeConvertedEvents() {
        guard let eventIds = selectedPlan?.createdEventIds, !eventIds.isEmpty else { return }
        for eventId in eventIds {
            try? calendarService.deleteEvent(identifier: eventId)
        }
        selectedPlan?.createdEventIds = nil
        selectedPlan?.lastConvertedAt = nil
        selectedPlan?.updatedAt = Date()
        markDirtyAndSave()
    }

    func dismissConversionResult() {
        conversionState = .idle
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
