import Foundation
import FirebaseFirestore

struct PlanObjective: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var text: String
    var isComplete: Bool
    var estimatedMinutes: Int?

    init(id: String = UUID().uuidString, text: String, isComplete: Bool = false, estimatedMinutes: Int? = nil) {
        self.id = id
        self.text = text
        self.isComplete = isComplete
        self.estimatedMinutes = estimatedMinutes
    }
}

struct OfficeHours: Codable, Equatable {
    var startTime: String   // "09:00" (HH:mm)
    var endTime: String     // "17:00" (HH:mm)
    var workDays: [Int]     // [2,3,4,5,6] = Mon-Fri (1=Sun..7=Sat)

    init(startTime: String = "09:00", endTime: String = "17:00", workDays: [Int] = [2, 3, 4, 5, 6]) {
        self.startTime = startTime
        self.endTime = endTime
        self.workDays = workDays
    }

    var totalMinutesPerDay: Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        guard let start = fmt.date(from: startTime),
              let end = fmt.date(from: endTime) else { return 0 }
        return max(0, Int(end.timeIntervalSince(start) / 60))
    }

    func isWorkDay(_ weekday: Int) -> Bool {
        workDays.contains(weekday)
    }

    var displayLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let displayFmt = DateFormatter()
        displayFmt.dateFormat = "h:mm a"
        let startStr: String
        let endStr: String
        if let s = fmt.date(from: startTime) {
            startStr = displayFmt.string(from: s)
        } else { startStr = startTime }
        if let e = fmt.date(from: endTime) {
            endStr = displayFmt.string(from: e)
        } else { endStr = endTime }

        let dayNames = workDays.sorted().compactMap { dayAbbr($0) }
        let daysStr = dayNames.joined(separator: ", ")
        return "\(startStr) – \(endStr), \(daysStr)"
    }

    private func dayAbbr(_ day: Int) -> String? {
        switch day {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return nil
        }
    }
}

struct Plan: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var title: String
    var startDate: String   // yyyy-MM-dd
    var endDate: String     // yyyy-MM-dd
    var overallObjectives: [PlanObjective]
    var dailyObjectives: [String: [PlanObjective]]  // keyed by yyyy-MM-dd
    var isComplete: Bool
    var createdAt: Date
    var updatedAt: Date
    var lastConvertedAt: Date?

    init(
        id: String? = nil,
        title: String,
        startDate: String,
        endDate: String,
        overallObjectives: [PlanObjective] = [],
        dailyObjectives: [String: [PlanObjective]] = [:],
        isComplete: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastConvertedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.overallObjectives = overallObjectives
        self.dailyObjectives = dailyObjectives
        self.isComplete = isComplete
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastConvertedAt = lastConvertedAt
    }

    // MARK: - Computed

    static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let dayOfWeekFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    var dateRange: [String] {
        guard let start = Plan.dateFmt.date(from: startDate),
              let end = Plan.dateFmt.date(from: endDate) else { return [] }
        var dates: [String] = []
        var current = start
        while current <= end {
            dates.append(Plan.dateFmt.string(from: current))
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }

    var dayCount: Int {
        dateRange.count
    }

    var displayDateRange: String {
        guard let start = Plan.dateFmt.date(from: startDate),
              let end = Plan.dateFmt.date(from: endDate) else { return "\(startDate) – \(endDate)" }
        return "\(Plan.displayFmt.string(from: start)) – \(Plan.displayFmt.string(from: end))"
    }

    var totalObjectives: Int {
        overallObjectives.count + dailyObjectives.values.reduce(0) { $0 + $1.count }
    }

    var completedObjectives: Int {
        let overallDone = overallObjectives.filter(\.isComplete).count
        let dailyDone = dailyObjectives.values.reduce(0) { $0 + $1.filter(\.isComplete).count }
        return overallDone + dailyDone
    }

    var progress: Double {
        guard totalObjectives > 0 else { return 0 }
        return Double(completedObjectives) / Double(totalObjectives)
    }

    static func displayDayLabel(for dateString: String) -> String {
        guard let date = dateFmt.date(from: dateString) else { return dateString }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today – \(dayOfWeekFmt.string(from: date))" }
        if cal.isDateInTomorrow(date) { return "Tomorrow – \(dayOfWeekFmt.string(from: date))" }
        if cal.isDateInYesterday(date) { return "Yesterday – \(dayOfWeekFmt.string(from: date))" }
        return dayOfWeekFmt.string(from: date)
    }

    static func suggestedTitle(start: Date, end: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        if days == 6, cal.component(.weekday, from: start) == 2 {
            return "Week of \(displayFmt.string(from: start))"
        }
        return ""
    }

    static var todayString: String {
        dateFmt.string(from: Date())
    }

    // MARK: - Calendar Conversion Helpers

    var hasAllDurationsSet: Bool {
        for dateStr in dateRange {
            let objectives = dailyObjectives[dateStr] ?? []
            for obj in objectives where !obj.isComplete {
                if obj.estimatedMinutes == nil || obj.estimatedMinutes == 0 {
                    return false
                }
            }
        }
        return true
    }

    var incompleteDailyObjectivesCount: Int {
        dailyObjectives.values.reduce(0) { $0 + $1.filter { !$0.isComplete }.count }
    }

    func totalMinutesForDay(_ dateString: String) -> Int {
        let objectives = dailyObjectives[dateString] ?? []
        return objectives.filter { !$0.isComplete }.compactMap(\.estimatedMinutes).reduce(0, +)
    }

    func daysWithMissingDurations() -> [String] {
        dateRange.filter { dateStr in
            let objectives = dailyObjectives[dateStr] ?? []
            return objectives.contains { !$0.isComplete && (($0.estimatedMinutes ?? 0) == 0) }
        }
    }
}
