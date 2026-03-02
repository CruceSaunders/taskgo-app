import Foundation
import FirebaseFirestore

struct PlanObjective: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var text: String
    var isComplete: Bool

    init(id: String = UUID().uuidString, text: String, isComplete: Bool = false) {
        self.id = id
        self.text = text
        self.isComplete = isComplete
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

    init(
        id: String? = nil,
        title: String,
        startDate: String,
        endDate: String,
        overallObjectives: [PlanObjective] = [],
        dailyObjectives: [String: [PlanObjective]] = [:],
        isComplete: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
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
    }

    // MARK: - Computed

    private static let dateFmt: DateFormatter = {
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
}
