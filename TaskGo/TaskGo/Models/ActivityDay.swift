import Foundation
import FirebaseFirestore

enum ActivityState: String, Codable {
    case active    // keyboard or clicks occurred
    case engaged   // scroll/movement only (reading, browsing)
    case present   // screen on, no input
}

enum DataSeries: String, CaseIterable, Codable, Identifiable {
    case keyboard = "Keyboard"
    case clicks = "Clicks"
    case scrolls = "Scrolls"
    case movement = "Movement"

    var id: String { rawValue }

    var color: String {
        switch self {
        case .keyboard: return "blue"
        case .clicks: return "green"
        case .scrolls: return "orange"
        case .movement: return "gray"
        }
    }

    var systemImage: String {
        switch self {
        case .keyboard: return "keyboard"
        case .clicks: return "cursorarrow.click.2"
        case .scrolls: return "scroll"
        case .movement: return "cursorarrow.motionlines"
        }
    }
}

struct MinuteEntry: Codable, Identifiable {
    var minute: Int         // 0-1439 (minute of day)
    var keyboard: Int
    var clicks: Int
    var scrolls: Int
    var movement: Int
    var state: ActivityState

    var id: Int { minute }

    var totalInputs: Int { keyboard + clicks + scrolls + movement }

    func value(for series: DataSeries) -> Int {
        switch series {
        case .keyboard: return keyboard
        case .clicks: return clicks
        case .scrolls: return scrolls
        case .movement: return movement
        }
    }
}

struct HourEntry: Codable, Identifiable {
    var hour: Int           // 0-23
    var keyboard: Int
    var clicks: Int
    var scrolls: Int
    var movement: Int
    var activeMinutes: Int
    var engagedMinutes: Int
    var presentMinutes: Int

    var id: Int { hour }

    var totalInputs: Int { keyboard + clicks + scrolls + movement }

    func value(for series: DataSeries) -> Int {
        switch series {
        case .keyboard: return keyboard
        case .clicks: return clicks
        case .scrolls: return scrolls
        case .movement: return movement
        }
    }

    static func empty(hour: Int) -> HourEntry {
        HourEntry(hour: hour, keyboard: 0, clicks: 0, scrolls: 0, movement: 0,
                  activeMinutes: 0, engagedMinutes: 0, presentMinutes: 0)
    }
}

struct ActivityDay: Codable, Identifiable {
    @DocumentID var id: String?
    var date: Date
    var minuteData: [MinuteEntry]
    var hourlySummary: [HourEntry]
    var totalKeyboard: Int
    var totalClicks: Int
    var totalScrolls: Int
    var totalMovement: Int
    var totalActiveMinutes: Int
    var totalEngagedMinutes: Int
    var totalPresentMinutes: Int
    var firstActivity: Date?
    var lastActivity: Date?

    var totalInputs: Int { totalKeyboard + totalClicks + totalScrolls + totalMovement }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    init(
        id: String? = nil,
        date: Date = Date(),
        minuteData: [MinuteEntry] = [],
        hourlySummary: [HourEntry]? = nil,
        totalKeyboard: Int = 0,
        totalClicks: Int = 0,
        totalScrolls: Int = 0,
        totalMovement: Int = 0,
        totalActiveMinutes: Int = 0,
        totalEngagedMinutes: Int = 0,
        totalPresentMinutes: Int = 0,
        firstActivity: Date? = nil,
        lastActivity: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.minuteData = minuteData
        self.hourlySummary = hourlySummary ?? (0..<24).map { HourEntry.empty(hour: $0) }
        self.totalKeyboard = totalKeyboard
        self.totalClicks = totalClicks
        self.totalScrolls = totalScrolls
        self.totalMovement = totalMovement
        self.totalActiveMinutes = totalActiveMinutes
        self.totalEngagedMinutes = totalEngagedMinutes
        self.totalPresentMinutes = totalPresentMinutes
        self.firstActivity = firstActivity
        self.lastActivity = lastActivity
    }

    mutating func addMinuteEntry(_ entry: MinuteEntry) {
        if let idx = minuteData.firstIndex(where: { $0.minute == entry.minute }) {
            minuteData[idx] = entry
        } else {
            minuteData.append(entry)
            minuteData.sort { $0.minute < $1.minute }
        }
        recalculateTotals()
    }

    mutating func recalculateTotals() {
        totalKeyboard = minuteData.reduce(0) { $0 + $1.keyboard }
        totalClicks = minuteData.reduce(0) { $0 + $1.clicks }
        totalScrolls = minuteData.reduce(0) { $0 + $1.scrolls }
        totalMovement = minuteData.reduce(0) { $0 + $1.movement }
        totalActiveMinutes = minuteData.filter { $0.state == .active }.count
        totalEngagedMinutes = minuteData.filter { $0.state == .engaged }.count
        totalPresentMinutes = minuteData.filter { $0.state == .present }.count

        rebuildHourlySummary()
    }

    mutating func rebuildHourlySummary() {
        var summary = (0..<24).map { HourEntry.empty(hour: $0) }
        for entry in minuteData {
            let h = entry.minute / 60
            guard h < 24 else { continue }
            summary[h].keyboard += entry.keyboard
            summary[h].clicks += entry.clicks
            summary[h].scrolls += entry.scrolls
            summary[h].movement += entry.movement
            switch entry.state {
            case .active: summary[h].activeMinutes += 1
            case .engaged: summary[h].engagedMinutes += 1
            case .present: summary[h].presentMinutes += 1
            }
        }
        hourlySummary = summary
    }

    static var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let bucketStart: Int    // minute of day
    let bucketEnd: Int
    let series: DataSeries
    let value: Int
    let label: String       // e.g. "9:00 AM" or "9:15 AM"
}
