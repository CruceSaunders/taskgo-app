import Foundation

enum ProductivityLevel: Int, Codable, CaseIterable, Comparable {
    case veryDistracting = -2
    case distracting = -1
    case neutral = 0
    case productive = 1
    case veryProductive = 2

    static func < (lhs: ProductivityLevel, rhs: ProductivityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .veryDistracting: return "Very Distracting"
        case .distracting: return "Distracting"
        case .neutral: return "Neutral"
        case .productive: return "Productive"
        case .veryProductive: return "Very Productive"
        }
    }

    var shortLabel: String {
        switch self {
        case .veryDistracting: return "V. Distracting"
        case .distracting: return "Distracting"
        case .neutral: return "Neutral"
        case .productive: return "Productive"
        case .veryProductive: return "V. Productive"
        }
    }

    var weight: Double {
        switch self {
        case .veryDistracting: return 0
        case .distracting: return 1
        case .neutral: return 2
        case .productive: return 3
        case .veryProductive: return 4
        }
    }
}

enum MatchField: String, Codable, CaseIterable {
    case bundleID
    case appName
    case windowTitle
    case domain
}

struct CategoryRule: Codable, Identifiable {
    let id: UUID
    var category: String
    var productivityLevel: ProductivityLevel
    var matchField: MatchField
    var pattern: String
    var isRegex: Bool
    var isDefault: Bool
    var priority: Int

    init(
        id: UUID = UUID(),
        category: String,
        productivityLevel: ProductivityLevel,
        matchField: MatchField,
        pattern: String,
        isRegex: Bool = false,
        isDefault: Bool = true,
        priority: Int = 0
    ) {
        self.id = id
        self.category = category
        self.productivityLevel = productivityLevel
        self.matchField = matchField
        self.pattern = pattern
        self.isRegex = isRegex
        self.isDefault = isDefault
        self.priority = priority
    }

    func matches(_ value: String) -> Bool {
        if isRegex {
            return (try? NSRegularExpression(pattern: pattern, options: .caseInsensitive))?
                .firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
        }
        return value.localizedCaseInsensitiveContains(pattern)
    }
}

struct CategoryResult {
    let category: String
    let productivityLevel: ProductivityLevel
    let matchedRule: CategoryRule?
}

struct TrackingPreferences: Codable {
    var trackWindowTitles: Bool = true
    var trackBrowserURLs: Bool = true
    var storeFullURLs: Bool = false

    static let storageKey = "trackingPreferences"

    static func load() -> TrackingPreferences {
        let url = preferencesURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let prefs = try? JSONDecoder().decode(TrackingPreferences.self, from: data) else {
            return TrackingPreferences()
        }
        return prefs
    }

    func save() {
        let url = Self.preferencesURL
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static var preferencesURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".taskgo")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("tracking-preferences.json")
    }
}
