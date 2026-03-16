import Foundation
import FirebaseFirestore

enum DataSeries: String, CaseIterable, Codable, Identifiable {
    case keyboard = "Keyboard"
    case clicks = "Clicks"
    case scrolls = "Scrolls"
    case movement = "Movement"

    var id: String { rawValue }

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

    var id: Int { minute }

    var totalInputs: Int { keyboard + clicks + scrolls + movement }

    var isActive: Bool { totalInputs > 0 }

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
        HourEntry(hour: hour, keyboard: 0, clicks: 0, scrolls: 0, movement: 0, activeMinutes: 0)
    }
}

struct ActivityDay: Codable, Identifiable {
    var id: String?
    var date: Date
    var minuteData: [MinuteEntry]
    var hourlySummary: [HourEntry]
    var totalKeyboard: Int
    var totalClicks: Int
    var totalScrolls: Int
    var totalMovement: Int
    var totalActiveMinutes: Int
    var firstActivity: Date?
    var lastActivity: Date?

    var totalInputs: Int { totalKeyboard + totalClicks + totalScrolls + totalMovement }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    init(
        date: Date = Date(),
        minuteData: [MinuteEntry] = [],
        hourlySummary: [HourEntry]? = nil,
        totalKeyboard: Int = 0,
        totalClicks: Int = 0,
        totalScrolls: Int = 0,
        totalMovement: Int = 0,
        totalActiveMinutes: Int = 0,
        firstActivity: Date? = nil,
        lastActivity: Date? = nil
    ) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.id = formatter.string(from: date)
        self.date = date
        self.minuteData = minuteData
        self.hourlySummary = hourlySummary ?? (0..<24).map { HourEntry.empty(hour: $0) }
        self.totalKeyboard = totalKeyboard
        self.totalClicks = totalClicks
        self.totalScrolls = totalScrolls
        self.totalMovement = totalMovement
        self.totalActiveMinutes = totalActiveMinutes
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
        totalActiveMinutes = minuteData.filter { $0.isActive }.count
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
            if entry.isActive { summary[h].activeMinutes += 1 }
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
    let bucketStart: Int
    let bucketEnd: Int
    let series: DataSeries
    let value: Int
    let label: String
}
