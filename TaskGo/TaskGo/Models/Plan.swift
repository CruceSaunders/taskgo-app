import Foundation
import FirebaseFirestore

enum PlanMode: String, Codable, Equatable, CaseIterable {
    case daily
    case weekly
    case timeline
}

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

struct Plan: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var title: String
    var mode: PlanMode
    var startDate: String   // yyyy-MM-dd
    var endDate: String     // yyyy-MM-dd
    var overallObjectives: [PlanObjective]
    var dailyObjectives: [String: [PlanObjective]]  // keyed by yyyy-MM-dd (day start or week start)
    var subDayObjectives: [String: [PlanObjective]]?  // day-level drill-down for weekly/timeline plans
    var sectionOrder: [String]?      // explicit ordering for timeline milestones
    var sectionTitles: [String: String]?  // custom titles for timeline milestones
    var isComplete: Bool
    var createdAt: Date
    var updatedAt: Date
    var lastConvertedAt: Date?
    var scheduleStartTime: String?  // "09:00" HH:mm -- per-plan schedule window
    var scheduleEndTime: String?    // "17:00" HH:mm
    var calendarId: String?
    var createdEventIds: [String]?
    var breakEnabled: Bool?
    var breakMinutes: Int?
    var breakCount: Int?

    init(
        id: String? = nil,
        title: String,
        mode: PlanMode = .daily,
        startDate: String,
        endDate: String,
        overallObjectives: [PlanObjective] = [],
        dailyObjectives: [String: [PlanObjective]] = [:],
        subDayObjectives: [String: [PlanObjective]]? = nil,
        sectionOrder: [String]? = nil,
        sectionTitles: [String: String]? = nil,
        isComplete: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastConvertedAt: Date? = nil,
        scheduleStartTime: String? = nil,
        scheduleEndTime: String? = nil,
        calendarId: String? = nil,
        createdEventIds: [String]? = nil,
        breakEnabled: Bool? = nil,
        breakMinutes: Int? = nil,
        breakCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.mode = mode
        self.startDate = startDate
        self.endDate = endDate
        self.overallObjectives = overallObjectives
        self.dailyObjectives = dailyObjectives
        self.subDayObjectives = subDayObjectives
        self.sectionOrder = sectionOrder
        self.sectionTitles = sectionTitles
        self.isComplete = isComplete
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastConvertedAt = lastConvertedAt
        self.scheduleStartTime = scheduleStartTime
        self.scheduleEndTime = scheduleEndTime
        self.calendarId = calendarId
        self.createdEventIds = createdEventIds
        self.breakEnabled = breakEnabled
        self.breakMinutes = breakMinutes
        self.breakCount = breakCount
    }

    enum CodingKeys: String, CodingKey {
        case id, title, mode, startDate, endDate, overallObjectives, dailyObjectives, subDayObjectives
        case sectionOrder, sectionTitles
        case isComplete, createdAt, updatedAt, lastConvertedAt
        case scheduleStartTime, scheduleEndTime, calendarId, createdEventIds
        case breakEnabled, breakMinutes, breakCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _id = try c.decode(DocumentID<String>.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        mode = try c.decodeIfPresent(PlanMode.self, forKey: .mode) ?? .daily
        startDate = try c.decode(String.self, forKey: .startDate)
        endDate = try c.decode(String.self, forKey: .endDate)
        overallObjectives = try c.decode([PlanObjective].self, forKey: .overallObjectives)
        dailyObjectives = try c.decode([String: [PlanObjective]].self, forKey: .dailyObjectives)
        subDayObjectives = try c.decodeIfPresent([String: [PlanObjective]].self, forKey: .subDayObjectives)
        sectionOrder = try c.decodeIfPresent([String].self, forKey: .sectionOrder)
        sectionTitles = try c.decodeIfPresent([String: String].self, forKey: .sectionTitles)
        isComplete = try c.decode(Bool.self, forKey: .isComplete)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        lastConvertedAt = try c.decodeIfPresent(Date.self, forKey: .lastConvertedAt)
        scheduleStartTime = try c.decodeIfPresent(String.self, forKey: .scheduleStartTime)
        scheduleEndTime = try c.decodeIfPresent(String.self, forKey: .scheduleEndTime)
        calendarId = try c.decodeIfPresent(String.self, forKey: .calendarId)
        createdEventIds = try c.decodeIfPresent([String].self, forKey: .createdEventIds)
        breakEnabled = try c.decodeIfPresent(Bool.self, forKey: .breakEnabled)
        breakMinutes = try c.decodeIfPresent(Int.self, forKey: .breakMinutes)
        breakCount = try c.decodeIfPresent(Int.self, forKey: .breakCount)
    }

    var hasScheduleConfig: Bool {
        scheduleStartTime != nil && scheduleEndTime != nil && calendarId != nil
    }

    var scheduleMinutesPerDay: Int {
        guard let st = scheduleStartTime, let et = scheduleEndTime else { return 0 }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        guard let start = fmt.date(from: st),
              let end = fmt.date(from: et) else { return 0 }
        return max(0, Int(end.timeIntervalSince(start) / 60))
    }

    var scheduleDisplayLabel: String? {
        guard let st = scheduleStartTime, let et = scheduleEndTime else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let displayFmt = DateFormatter()
        displayFmt.dateFormat = "h:mm a"
        guard let s = fmt.date(from: st), let e = fmt.date(from: et) else { return nil }
        return "\(displayFmt.string(from: s)) – \(displayFmt.string(from: e))"
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

    var weekRange: [String] {
        guard let start = Plan.dateFmt.date(from: startDate),
              let end = Plan.dateFmt.date(from: endDate) else { return [] }
        var weeks: [String] = []
        var current = start
        while current <= end {
            weeks.append(Plan.dateFmt.string(from: current))
            guard let next = Calendar.current.date(byAdding: .day, value: 7, to: current) else { break }
            current = next
        }
        return weeks
    }

    var weekCount: Int {
        weekRange.count
    }

    var periodKeys: [String] {
        switch mode {
        case .timeline: return sectionOrder ?? []
        case .weekly:   return weekRange
        case .daily:    return dateRange
        }
    }

    var periodCount: Int {
        periodKeys.count
    }

    var displayDateRange: String {
        guard let start = Plan.dateFmt.date(from: startDate),
              let end = Plan.dateFmt.date(from: endDate) else { return "\(startDate) – \(endDate)" }
        return "\(Plan.displayFmt.string(from: start)) – \(Plan.displayFmt.string(from: end))"
    }

    func daysInWeek(startingFrom weekKey: String) -> [String] {
        guard let start = Plan.dateFmt.date(from: weekKey),
              let planEnd = Plan.dateFmt.date(from: endDate) else { return [] }
        var days: [String] = []
        for offset in 0..<7 {
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: start) else { break }
            if day > planEnd { break }
            days.append(Plan.dateFmt.string(from: day))
        }
        return days
    }

    var totalObjectives: Int {
        let sub = subDayObjectives?.values.reduce(0) { $0 + $1.count } ?? 0
        return overallObjectives.count + dailyObjectives.values.reduce(0) { $0 + $1.count } + sub
    }

    var completedObjectives: Int {
        let overallDone = overallObjectives.filter(\.isComplete).count
        let dailyDone = dailyObjectives.values.reduce(0) { $0 + $1.filter(\.isComplete).count }
        let subDone = subDayObjectives?.values.reduce(0) { $0 + $1.filter(\.isComplete).count } ?? 0
        return overallDone + dailyDone + subDone
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

    static func displayWeekLabel(for weekStartString: String) -> String {
        guard let start = dateFmt.date(from: weekStartString) else { return weekStartString }
        let cal = Calendar.current
        guard let end = cal.date(byAdding: .day, value: 6, to: start) else { return weekStartString }
        let range = "\(displayFmt.string(from: start)) – \(displayFmt.string(from: end))"
        if cal.isDate(Date(), equalTo: start, toGranularity: .weekOfYear) {
            return "This Week – \(range)"
        }
        if let nextWeekStart = cal.date(byAdding: .weekOfYear, value: 1, to: cal.startOfDay(for: Date())),
           cal.isDate(start, equalTo: nextWeekStart, toGranularity: .weekOfYear) {
            return "Next Week – \(range)"
        }
        return "Week of \(displayFmt.string(from: start))"
    }

    func displayPeriodLabel(for key: String) -> String {
        switch mode {
        case .timeline: return sectionTitles?[key] ?? "Untitled"
        case .weekly:   return Plan.displayWeekLabel(for: key)
        case .daily:    return Plan.displayDayLabel(for: key)
        }
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

    func maxBreaksForDay(_ dateString: String) -> Int {
        let bm = breakMinutes ?? 10
        guard bm > 0 else { return 0 }
        let taskMinutes = totalMinutesForDay(dateString)
        let freeMinutes = scheduleMinutesPerDay - taskMinutes
        guard freeMinutes > 0 else { return 0 }
        let taskCount = (dailyObjectives[dateString] ?? []).filter { !$0.isComplete }.count
        let maxGaps = max(0, taskCount - 1)
        return min(freeMinutes / bm, maxGaps)
    }

    func effectiveBreakCountForDay(_ dateString: String) -> Int {
        guard breakEnabled == true else { return 0 }
        let requested = breakCount ?? 2
        return min(requested, maxBreaksForDay(dateString))
    }

    func totalBreakMinutesForDay(_ dateString: String) -> Int {
        effectiveBreakCountForDay(dateString) * (breakMinutes ?? 10)
    }
}
