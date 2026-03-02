import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class RecurrenceService: ObservableObject {
    static let shared = RecurrenceService()

    private let firestoreService = FirestoreService.shared
    private var timer: Timer?
    private var isProcessing = false

    private init() {}

    func start() {
        stop()
        processRecurringTasks()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processRecurringTasks()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func processRecurringTasks() {
        guard !isProcessing else { return }
        guard let userId = Auth.auth().currentUser?.uid else { return }

        isProcessing = true

        Task {
            defer { isProcessing = false }

            do {
                let dueTasks = try await firestoreService.getRecurringTasks(userId: userId)

                for task in dueTasks {
                    guard let recurrence = task.recurrence else { continue }

                    if let endDate = recurrence.endDate, endDate < Date() {
                        var expired = task
                        expired.nextOccurrence = nil
                        try? await firestoreService.updateTask(expired, userId: userId)
                        continue
                    }

                    try await spawnInstance(from: task, userId: userId)

                    var updated = task
                    updated.nextOccurrence = computeNextOccurrence(from: Date(), rule: recurrence)
                    try? await firestoreService.updateTask(updated, userId: userId)
                }
            } catch {
                print("[RecurrenceService] error: \(error)")
            }
        }
    }

    private func spawnInstance(from source: TaskItem, userId: String) async throws {
        let instance = TaskItem(
            name: source.name,
            description: source.description,
            timeEstimate: source.timeEstimate,
            position: 1,
            groupId: source.groupId,
            colorTag: source.colorTag,
            sourceTaskId: source.id
        )

        try await firestoreService.shiftTaskPositions(
            groupId: source.groupId,
            userId: userId,
            fromPosition: 1
        )
        _ = try await firestoreService.createTask(instance, userId: userId)
    }

    // MARK: - Next Occurrence Calculation

    func computeNextOccurrence(from date: Date, rule: RecurrenceRule) -> Date? {
        let calendar = Calendar.current

        guard !rule.timesOfDay.isEmpty else { return nil }

        switch rule.frequency {
        case "daily":
            return nextDailyOccurrence(from: date, interval: rule.interval, times: rule.timesOfDay, calendar: calendar)
        case "weekly":
            return nextWeeklyOccurrence(from: date, interval: rule.interval, days: rule.daysOfWeek ?? [], times: rule.timesOfDay, calendar: calendar)
        case "monthly":
            let components = parseTime(rule.timesOfDay.first ?? "09:00")
            var next = calendar.date(byAdding: .month, value: rule.interval, to: date) ?? date
            next = calendar.date(bySettingHour: components.hour, minute: components.minute, second: 0, of: next) ?? next
            return next
        case "custom":
            if let days = rule.daysOfWeek, !days.isEmpty {
                return nextWeeklyOccurrence(from: date, interval: 1, days: days, times: rule.timesOfDay, calendar: calendar)
            }
            return nextDailyOccurrence(from: date, interval: rule.interval, times: rule.timesOfDay, calendar: calendar)
        default:
            return nil
        }
    }

    private func nextDailyOccurrence(from date: Date, interval: Int, times: [String], calendar: Calendar) -> Date? {
        let sortedTimes = times.sorted()

        for timeStr in sortedTimes {
            let tc = parseTime(timeStr)
            if let candidate = calendar.date(bySettingHour: tc.hour, minute: tc.minute, second: 0, of: date),
               candidate > date {
                return candidate
            }
        }

        guard let nextDay = calendar.date(byAdding: .day, value: interval, to: date) else { return nil }
        let tc = parseTime(sortedTimes.first ?? "09:00")
        return calendar.date(bySettingHour: tc.hour, minute: tc.minute, second: 0, of: nextDay)
    }

    private func nextWeeklyOccurrence(from date: Date, interval: Int, days: [Int], times: [String], calendar: Calendar) -> Date? {
        let sortedDays = days.sorted()
        let sortedTimes = times.sorted()
        guard !sortedDays.isEmpty, !sortedTimes.isEmpty else { return nil }

        let currentWeekday = calendar.component(.weekday, from: date)

        for day in sortedDays where day >= currentWeekday {
            for timeStr in sortedTimes {
                let tc = parseTime(timeStr)
                let daysAhead = day - currentWeekday
                guard let targetDate = calendar.date(byAdding: .day, value: daysAhead, to: date) else { continue }
                if let candidate = calendar.date(bySettingHour: tc.hour, minute: tc.minute, second: 0, of: targetDate),
                   candidate > date {
                    return candidate
                }
            }
        }

        let daysUntilNextWeek = (7 * interval) - (currentWeekday - sortedDays.first!) + (currentWeekday > sortedDays.first! ? 0 : 7 * (interval - 1))
        guard let nextWeekStart = calendar.date(byAdding: .day, value: max(daysUntilNextWeek, 1), to: date) else { return nil }
        let firstDay = sortedDays.first!
        let nextWeekday = calendar.component(.weekday, from: nextWeekStart)
        let adjust = (firstDay - nextWeekday + 7) % 7
        guard let targetDate = calendar.date(byAdding: .day, value: adjust, to: nextWeekStart) else { return nil }
        let tc = parseTime(sortedTimes.first!)
        return calendar.date(bySettingHour: tc.hour, minute: tc.minute, second: 0, of: targetDate)
    }

    private func parseTime(_ timeStr: String) -> (hour: Int, minute: Int) {
        let parts = timeStr.split(separator: ":").map { Int($0) ?? 0 }
        return (parts.first ?? 9, parts.count > 1 ? parts[1] : 0)
    }

    func computeInitialNextOccurrence(rule: RecurrenceRule) -> Date? {
        computeNextOccurrence(from: Date(), rule: rule)
    }
}
