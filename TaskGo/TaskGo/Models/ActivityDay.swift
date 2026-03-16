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
    var dictation: Int
    var meeting: Int        // 1 if user was in a calendar meeting this minute

    var id: Int { minute }

    var totalInputs: Int { keyboard + clicks + scrolls + movement }

    var meaningfulInputs: Int { keyboard + clicks + dictation }

    var isActive: Bool { totalInputs > 0 || dictation > 0 || meeting > 0 }

    func value(for series: DataSeries) -> Int {
        switch series {
        case .keyboard: return keyboard
        case .clicks: return clicks
        case .scrolls: return scrolls
        case .movement: return movement
        }
    }

    init(minute: Int, keyboard: Int, clicks: Int, scrolls: Int, movement: Int, dictation: Int = 0, meeting: Int = 0) {
        self.minute = minute
        self.keyboard = keyboard
        self.clicks = clicks
        self.scrolls = scrolls
        self.movement = movement
        self.dictation = dictation
        self.meeting = meeting
    }

    enum CodingKeys: String, CodingKey {
        case minute, keyboard, clicks, scrolls, movement, dictation, meeting
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minute = try container.decode(Int.self, forKey: .minute)
        keyboard = try container.decode(Int.self, forKey: .keyboard)
        clicks = try container.decode(Int.self, forKey: .clicks)
        scrolls = try container.decode(Int.self, forKey: .scrolls)
        movement = try container.decode(Int.self, forKey: .movement)
        dictation = try container.decodeIfPresent(Int.self, forKey: .dictation) ?? 0
        meeting = try container.decodeIfPresent(Int.self, forKey: .meeting) ?? 0
    }
}

struct HourEntry: Codable, Identifiable {
    var hour: Int           // 0-23
    var keyboard: Int
    var clicks: Int
    var scrolls: Int
    var movement: Int
    var activeMinutes: Int
    var dictation: Int
    var meetingMinutes: Int

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
        HourEntry(hour: hour, keyboard: 0, clicks: 0, scrolls: 0, movement: 0, activeMinutes: 0, dictation: 0, meetingMinutes: 0)
    }

    enum CodingKeys: String, CodingKey {
        case hour, keyboard, clicks, scrolls, movement, activeMinutes, dictation, meetingMinutes
    }

    init(hour: Int, keyboard: Int, clicks: Int, scrolls: Int, movement: Int, activeMinutes: Int, dictation: Int = 0, meetingMinutes: Int = 0) {
        self.hour = hour
        self.keyboard = keyboard
        self.clicks = clicks
        self.scrolls = scrolls
        self.movement = movement
        self.activeMinutes = activeMinutes
        self.dictation = dictation
        self.meetingMinutes = meetingMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hour = try container.decode(Int.self, forKey: .hour)
        keyboard = try container.decode(Int.self, forKey: .keyboard)
        clicks = try container.decode(Int.self, forKey: .clicks)
        scrolls = try container.decode(Int.self, forKey: .scrolls)
        movement = try container.decode(Int.self, forKey: .movement)
        activeMinutes = try container.decode(Int.self, forKey: .activeMinutes)
        dictation = try container.decodeIfPresent(Int.self, forKey: .dictation) ?? 0
        meetingMinutes = try container.decodeIfPresent(Int.self, forKey: .meetingMinutes) ?? 0
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
    var totalDictation: Int
    var totalMeetingMinutes: Int
    var totalActiveMinutes: Int
    var firstActivity: Date?
    var lastActivity: Date?

    var totalInputs: Int { totalKeyboard + totalClicks + totalScrolls + totalMovement }

    var meaningfulInputs: Int { totalKeyboard + totalClicks + totalDictation }

    var engagedMinutes: Int {
        minuteData.filter { $0.keyboard > 0 || $0.dictation > 0 || $0.clicks > 0 }.count
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    enum CodingKeys: String, CodingKey {
        case id, date, minuteData, hourlySummary
        case totalKeyboard, totalClicks, totalScrolls, totalMovement, totalDictation
        case totalMeetingMinutes, totalActiveMinutes, firstActivity, lastActivity
    }

    init(
        date: Date = Date(),
        minuteData: [MinuteEntry] = [],
        hourlySummary: [HourEntry]? = nil,
        totalKeyboard: Int = 0,
        totalClicks: Int = 0,
        totalScrolls: Int = 0,
        totalMovement: Int = 0,
        totalDictation: Int = 0,
        totalMeetingMinutes: Int = 0,
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
        self.totalDictation = totalDictation
        self.totalMeetingMinutes = totalMeetingMinutes
        self.totalActiveMinutes = totalActiveMinutes
        self.firstActivity = firstActivity
        self.lastActivity = lastActivity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        minuteData = try container.decode([MinuteEntry].self, forKey: .minuteData)
        hourlySummary = try container.decode([HourEntry].self, forKey: .hourlySummary)
        totalKeyboard = try container.decode(Int.self, forKey: .totalKeyboard)
        totalClicks = try container.decode(Int.self, forKey: .totalClicks)
        totalScrolls = try container.decode(Int.self, forKey: .totalScrolls)
        totalMovement = try container.decode(Int.self, forKey: .totalMovement)
        totalDictation = try container.decodeIfPresent(Int.self, forKey: .totalDictation) ?? 0
        totalMeetingMinutes = try container.decodeIfPresent(Int.self, forKey: .totalMeetingMinutes) ?? 0
        totalActiveMinutes = try container.decode(Int.self, forKey: .totalActiveMinutes)
        firstActivity = try container.decodeIfPresent(Date.self, forKey: .firstActivity)
        lastActivity = try container.decodeIfPresent(Date.self, forKey: .lastActivity)
    }

    mutating func addMinuteEntry(_ entry: MinuteEntry) {
        if let idx = minuteData.firstIndex(where: { $0.minute == entry.minute }) {
            minuteData[idx].keyboard += entry.keyboard
            minuteData[idx].clicks += entry.clicks
            minuteData[idx].scrolls += entry.scrolls
            minuteData[idx].movement += entry.movement
            minuteData[idx].dictation += entry.dictation
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
        totalDictation = minuteData.reduce(0) { $0 + $1.dictation }
        totalMeetingMinutes = minuteData.filter { $0.meeting > 0 }.count
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
            summary[h].dictation += entry.dictation
            if entry.meeting > 0 { summary[h].meetingMinutes += 1 }
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
