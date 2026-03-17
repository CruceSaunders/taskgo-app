import Foundation
import FirebaseFirestore

enum DataSeries: String, CaseIterable, Codable, Identifiable {
    case keyboard = "Keyboard"
    case clicks = "Clicks"
    case scrolls = "Scrolls"
    case movement = "Movement"
    case speaking = "Speaking"
    case watching = "Watching"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .keyboard: return "keyboard"
        case .clicks: return "cursorarrow.click.2"
        case .scrolls: return "scroll"
        case .movement: return "cursorarrow.motionlines"
        case .speaking: return "mic.fill"
        case .watching: return "play.rectangle.fill"
        }
    }
}

// MARK: - App Tracking Models

struct AppSegment: Codable, Identifiable {
    var id: UUID = UUID()
    let bundleID: String
    let appName: String
    let windowTitle: String
    let domain: String?
    let category: String
    let productivityScore: Int
    var seconds: Int
    var taskName: String?

    enum CodingKeys: String, CodingKey {
        case id, bundleID, appName, windowTitle, domain, category, productivityScore, seconds, taskName
    }

    init(bundleID: String, appName: String, windowTitle: String, domain: String? = nil,
         category: String, productivityScore: Int, seconds: Int, taskName: String? = nil) {
        self.id = UUID()
        self.bundleID = bundleID
        self.appName = appName
        self.windowTitle = windowTitle
        self.domain = domain
        self.category = category
        self.productivityScore = productivityScore
        self.seconds = seconds
        self.taskName = taskName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        bundleID = try container.decode(String.self, forKey: .bundleID)
        appName = try container.decode(String.self, forKey: .appName)
        windowTitle = try container.decode(String.self, forKey: .windowTitle)
        domain = try container.decodeIfPresent(String.self, forKey: .domain)
        category = try container.decode(String.self, forKey: .category)
        productivityScore = try container.decode(Int.self, forKey: .productivityScore)
        seconds = try container.decode(Int.self, forKey: .seconds)
        taskName = try container.decodeIfPresent(String.self, forKey: .taskName)
    }
}

struct AppDaySummary: Codable, Identifiable {
    var id: String { bundleID }
    let bundleID: String
    let appName: String
    let category: String
    let productivityScore: Int
    var totalSeconds: Int

    enum CodingKeys: String, CodingKey {
        case bundleID, appName, category, productivityScore, totalSeconds
    }
}

struct TimelineSegment: Identifiable {
    let id = UUID()
    let startMinute: Int
    let endMinute: Int
    let appName: String
    let bundleID: String
    let category: String
    let productivityScore: Int
    let windowTitle: String
    let domain: String?
}

struct MinuteEntry: Codable, Identifiable {
    var minute: Int         // 0-1439 (minute of day)
    var keyboard: Int
    var clicks: Int
    var scrolls: Int
    var movement: Int
    var dictation: Int
    var meeting: Int        // 1 if mic was active (speaking/call)
    var watching: Int       // 1 if media was playing

    var appSegments: [AppSegment]?
    var dominantApp: String?
    var dominantCategory: String?
    var minuteProductivityScore: Double?

    var id: Int { minute }

    var totalInputs: Int { keyboard + clicks + scrolls + movement }

    var meaningfulInputs: Int { keyboard + clicks + dictation }

    var isActive: Bool {
        totalInputs > 0 || dictation > 0 || meeting > 0 || watching > 0
        || (appSegments != nil && !(appSegments?.isEmpty ?? true))
    }

    func value(for series: DataSeries) -> Int {
        switch series {
        case .keyboard: return keyboard
        case .clicks: return clicks
        case .scrolls: return scrolls
        case .movement: return movement
        case .speaking: return meeting
        case .watching: return watching
        }
    }

    init(minute: Int, keyboard: Int, clicks: Int, scrolls: Int, movement: Int,
         dictation: Int = 0, meeting: Int = 0, watching: Int = 0,
         appSegments: [AppSegment]? = nil) {
        self.minute = minute
        self.keyboard = keyboard
        self.clicks = clicks
        self.scrolls = scrolls
        self.movement = movement
        self.dictation = dictation
        self.meeting = meeting
        self.watching = watching
        self.appSegments = appSegments

        if let segs = appSegments, !segs.isEmpty {
            let dominant = segs.max(by: { $0.seconds < $1.seconds })
            self.dominantApp = dominant?.appName
            self.dominantCategory = dominant?.category
            let total = segs.reduce(0) { $0 + $1.seconds }
            if total > 0 {
                let weighted = segs.reduce(0.0) { $0 + Double($1.productivityScore) * Double($1.seconds) }
                self.minuteProductivityScore = weighted / Double(total)
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case minute, keyboard, clicks, scrolls, movement, dictation, meeting, watching
        case appSegments, dominantApp, dominantCategory, minuteProductivityScore
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
        watching = try container.decodeIfPresent(Int.self, forKey: .watching) ?? 0
        appSegments = try container.decodeIfPresent([AppSegment].self, forKey: .appSegments)
        dominantApp = try container.decodeIfPresent(String.self, forKey: .dominantApp)
        dominantCategory = try container.decodeIfPresent(String.self, forKey: .dominantCategory)
        minuteProductivityScore = try container.decodeIfPresent(Double.self, forKey: .minuteProductivityScore)
    }

    mutating func recomputeDominant() {
        guard let segs = appSegments, !segs.isEmpty else { return }
        let dominant = segs.max(by: { $0.seconds < $1.seconds })
        dominantApp = dominant?.appName
        dominantCategory = dominant?.category
        let total = segs.reduce(0) { $0 + $1.seconds }
        if total > 0 {
            let weighted = segs.reduce(0.0) { $0 + Double($1.productivityScore) * Double($1.seconds) }
            minuteProductivityScore = weighted / Double(total)
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
    var dictation: Int
    var meetingMinutes: Int
    var watchingMinutes: Int

    var id: Int { hour }

    var totalInputs: Int { keyboard + clicks + scrolls + movement }

    func value(for series: DataSeries) -> Int {
        switch series {
        case .keyboard: return keyboard
        case .clicks: return clicks
        case .scrolls: return scrolls
        case .movement: return movement
        case .speaking: return meetingMinutes
        case .watching: return watchingMinutes
        }
    }

    static func empty(hour: Int) -> HourEntry {
        HourEntry(hour: hour, keyboard: 0, clicks: 0, scrolls: 0, movement: 0, activeMinutes: 0, dictation: 0, meetingMinutes: 0, watchingMinutes: 0)
    }

    enum CodingKeys: String, CodingKey {
        case hour, keyboard, clicks, scrolls, movement, activeMinutes, dictation, meetingMinutes, watchingMinutes
    }

    init(hour: Int, keyboard: Int, clicks: Int, scrolls: Int, movement: Int, activeMinutes: Int, dictation: Int = 0, meetingMinutes: Int = 0, watchingMinutes: Int = 0) {
        self.hour = hour
        self.keyboard = keyboard
        self.clicks = clicks
        self.scrolls = scrolls
        self.movement = movement
        self.activeMinutes = activeMinutes
        self.dictation = dictation
        self.meetingMinutes = meetingMinutes
        self.watchingMinutes = watchingMinutes
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
        watchingMinutes = try container.decodeIfPresent(Int.self, forKey: .watchingMinutes) ?? 0
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

    var productivityPulse: Double?
    var appSummary: [AppDaySummary]?

    var totalInputs: Int { totalKeyboard + totalClicks + totalScrolls + totalMovement }

    var meaningfulInputs: Int { totalKeyboard + totalClicks + totalDictation }

    var engagedMinutes: Int {
        minuteData.filter { $0.keyboard > 0 || $0.dictation > 0 || $0.clicks > 0 }.count
    }

    var hasAppTrackingData: Bool {
        minuteData.contains { $0.appSegments != nil && !($0.appSegments?.isEmpty ?? true) }
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
        case productivityPulse, appSummary
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
        totalActiveMinutes = try container.decodeIfPresent(Int.self, forKey: .totalActiveMinutes) ?? 0
        firstActivity = try container.decodeIfPresent(Date.self, forKey: .firstActivity)
        lastActivity = try container.decodeIfPresent(Date.self, forKey: .lastActivity)
        productivityPulse = try container.decodeIfPresent(Double.self, forKey: .productivityPulse)
        appSummary = try container.decodeIfPresent([AppDaySummary].self, forKey: .appSummary)
    }

    mutating func addMinuteEntry(_ entry: MinuteEntry) {
        if let idx = minuteData.firstIndex(where: { $0.minute == entry.minute }) {
            minuteData[idx].keyboard += entry.keyboard
            minuteData[idx].clicks += entry.clicks
            minuteData[idx].scrolls += entry.scrolls
            minuteData[idx].movement += entry.movement
            minuteData[idx].dictation += entry.dictation
            minuteData[idx].meeting = max(minuteData[idx].meeting, entry.meeting)
            minuteData[idx].watching = max(minuteData[idx].watching, entry.watching)
            if let newSegs = entry.appSegments {
                if minuteData[idx].appSegments == nil {
                    minuteData[idx].appSegments = newSegs
                } else {
                    minuteData[idx].appSegments?.append(contentsOf: newSegs)
                }
                minuteData[idx].recomputeDominant()
            }
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
        rebuildAppSummary()
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
            if entry.watching > 0 { summary[h].watchingMinutes += 1 }
            if entry.isActive { summary[h].activeMinutes += 1 }
        }
        hourlySummary = summary
    }

    mutating func rebuildAppSummary() {
        var byBundle: [String: AppDaySummary] = [:]
        var allSegments: [AppSegment] = []

        for entry in minuteData {
            guard let segs = entry.appSegments else { continue }
            allSegments.append(contentsOf: segs)
            for seg in segs {
                if var existing = byBundle[seg.bundleID] {
                    existing.totalSeconds += seg.seconds
                    byBundle[seg.bundleID] = existing
                } else {
                    byBundle[seg.bundleID] = AppDaySummary(
                        bundleID: seg.bundleID,
                        appName: seg.appName,
                        category: seg.category,
                        productivityScore: seg.productivityScore,
                        totalSeconds: seg.seconds
                    )
                }
            }
        }
        appSummary = byBundle.values.sorted { $0.totalSeconds > $1.totalSeconds }
        productivityPulse = CategoryEngine.productivityPulse(from: allSegments)
    }

    static var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Data Integrity Validation

    func validateIntegrity() -> [String] {
        var violations: [String] = []

        for entry in minuteData {
            if entry.minute < 0 || entry.minute > 1439 {
                violations.append("[RANGE] Minute \(entry.minute) out of valid range 0-1439")
            }
        }

        let computedActiveMinutes = minuteData.filter { $0.isActive }.count
        if computedActiveMinutes != totalActiveMinutes {
            violations.append("[ACTIVE] totalActiveMinutes (\(totalActiveMinutes)) != computed active count (\(computedActiveMinutes))")
        }

        let computedKeyboard = minuteData.reduce(0) { $0 + $1.keyboard }
        if computedKeyboard != totalKeyboard {
            violations.append("[SUM] totalKeyboard (\(totalKeyboard)) != sum of minute keyboard (\(computedKeyboard))")
        }
        let computedClicks = minuteData.reduce(0) { $0 + $1.clicks }
        if computedClicks != totalClicks {
            violations.append("[SUM] totalClicks (\(totalClicks)) != sum of minute clicks (\(computedClicks))")
        }

        for entry in minuteData {
            if let segs = entry.appSegments, !segs.isEmpty {
                if entry.dominantApp == nil {
                    violations.append("[DOMINANT] Minute \(entry.minute) has \(segs.count) segments but no dominantApp")
                }
                for seg in segs {
                    if seg.seconds > 300 {
                        violations.append("[SEGMENT] Minute \(entry.minute) segment \(seg.appName) has \(seg.seconds)s (>300s max)")
                    }
                    if seg.seconds <= 0 {
                        violations.append("[SEGMENT] Minute \(entry.minute) segment \(seg.appName) has \(seg.seconds)s (<=0)")
                    }
                }
            }
        }

        if let summary = appSummary {
            var segmentSumByBundle: [String: Int] = [:]
            for entry in minuteData {
                guard let segs = entry.appSegments else { continue }
                for seg in segs {
                    segmentSumByBundle[seg.bundleID, default: 0] += seg.seconds
                }
            }
            for app in summary {
                let segSum = segmentSumByBundle[app.bundleID] ?? 0
                if app.totalSeconds != segSum {
                    violations.append("[APPSUMMARY] \(app.appName) summary (\(app.totalSeconds)s) != segment sum (\(segSum)s)")
                }
            }
        }

        for h in 0..<24 {
            guard h < hourlySummary.count else { continue }
            let minutesInHour = minuteData.filter { $0.minute / 60 == h && $0.isActive }.count
            if hourlySummary[h].activeMinutes != minutesInHour {
                violations.append("[HOURLY] Hour \(h) activeMinutes (\(hourlySummary[h].activeMinutes)) != computed (\(minutesInHour))")
            }
        }

        if hasAppTrackingData {
            var allSegs: [AppSegment] = []
            for entry in minuteData {
                if let segs = entry.appSegments { allSegs.append(contentsOf: segs) }
            }
            let recomputedPulse = CategoryEngine.productivityPulse(from: allSegs)
            if let storedPulse = productivityPulse, abs(storedPulse - recomputedPulse) > 0.1 {
                violations.append("[PULSE] Stored pulse (\(String(format: "%.1f", storedPulse))) != recomputed (\(String(format: "%.1f", recomputedPulse)))")
            }
        }

        return violations
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

struct ProductivityDataPoint: Identifiable {
    let id = UUID()
    let bucketStart: Int
    let activeMinutes: Int
    let maxPossible: Int
}

enum ActivityViewMode: String, CaseIterable {
    case activity = "Activity"
    case productivity = "Productivity"
}
