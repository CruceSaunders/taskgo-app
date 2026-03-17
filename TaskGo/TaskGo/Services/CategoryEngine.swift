import Foundation

class CategoryEngine {
    static let shared = CategoryEngine()

    private var defaultRules: [CategoryRule] = []
    private var userRules: [CategoryRule] = []

    private let userRulesURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".taskgo")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("category-rules.json")
    }()

    var allRules: [CategoryRule] {
        (userRules + defaultRules).sorted { $0.priority > $1.priority }
    }

    private init() {
        defaultRules = Self.buildDefaultRules()
        loadUserRules()
    }

    // MARK: - Classification

    func classify(bundleID: String, appName: String, windowTitle: String, domain: String?) -> CategoryResult {
        let fields: [(MatchField, String)] = [
            (.domain, domain ?? ""),
            (.bundleID, bundleID),
            (.windowTitle, windowTitle),
            (.appName, appName)
        ]

        let sortedRules = allRules

        for rule in sortedRules {
            guard let value = fields.first(where: { $0.0 == rule.matchField })?.1,
                  !value.isEmpty else { continue }
            if rule.matches(value) {
                return CategoryResult(
                    category: rule.category,
                    productivityLevel: rule.productivityLevel,
                    matchedRule: rule
                )
            }
        }

        return CategoryResult(category: "Other", productivityLevel: .neutral, matchedRule: nil)
    }

    // MARK: - Productivity Pulse (RescueTime formula)

    static func productivityPulse(from segments: [AppSegment]) -> Double {
        guard !segments.isEmpty else { return 0 }
        let totalSeconds = segments.reduce(0) { $0 + $1.seconds }
        guard totalSeconds > 0 else { return 0 }

        var weightedSum: Double = 0
        for seg in segments {
            let level = ProductivityLevel(rawValue: seg.productivityScore) ?? .neutral
            weightedSum += level.weight * Double(seg.seconds)
        }

        return (weightedSum / (Double(totalSeconds) * 4.0)) * 100.0
    }

    // MARK: - User Rules Management

    func loadUserRules() {
        guard FileManager.default.fileExists(atPath: userRulesURL.path),
              let data = try? Data(contentsOf: userRulesURL),
              let rules = try? JSONDecoder().decode([CategoryRule].self, from: data) else {
            userRules = []
            return
        }
        userRules = rules
    }

    func saveUserRules() {
        if let data = try? JSONEncoder().encode(userRules) {
            try? data.write(to: userRulesURL, options: .atomic)
        }
    }

    func addUserRule(_ rule: CategoryRule) {
        var mutable = rule
        mutable = CategoryRule(
            id: rule.id,
            category: rule.category,
            productivityLevel: rule.productivityLevel,
            matchField: rule.matchField,
            pattern: rule.pattern,
            isRegex: rule.isRegex,
            isDefault: false,
            priority: 1000 + userRules.count
        )
        userRules.append(mutable)
        saveUserRules()
    }

    func removeUserRule(id: UUID) {
        userRules.removeAll { $0.id == id }
        saveUserRules()
    }

    func updateUserRule(_ rule: CategoryRule) {
        if let idx = userRules.firstIndex(where: { $0.id == rule.id }) {
            userRules[idx] = rule
            saveUserRules()
        }
    }

    func resetToDefaults() {
        userRules = []
        saveUserRules()
    }

    var userRuleCount: Int { userRules.count }
    var defaultRuleCount: Int { defaultRules.count }

    // MARK: - Default Rules

    private static func buildDefaultRules() -> [CategoryRule] {
        var rules: [CategoryRule] = []
        var p = 100

        func add(_ category: String, _ level: ProductivityLevel, _ field: MatchField, _ pattern: String, regex: Bool = false) {
            rules.append(CategoryRule(
                category: category,
                productivityLevel: level,
                matchField: field,
                pattern: pattern,
                isRegex: regex,
                isDefault: true,
                priority: p
            ))
            p -= 1
        }

        // ── Coding (+2) ──
        add("Coding", .veryProductive, .bundleID, "com.apple.dt.Xcode")
        add("Coding", .veryProductive, .bundleID, "com.microsoft.VSCode")
        add("Coding", .veryProductive, .bundleID, "com.todesktop.230313mzl4w4u92")
        add("Coding", .veryProductive, .appName, "Cursor")
        add("Coding", .veryProductive, .bundleID, "com.sublimetext")
        add("Coding", .veryProductive, .bundleID, "com.jetbrains")
        add("Coding", .veryProductive, .appName, "IntelliJ")
        add("Coding", .veryProductive, .appName, "PyCharm")
        add("Coding", .veryProductive, .appName, "WebStorm")
        add("Coding", .veryProductive, .appName, "CLion")
        add("Coding", .veryProductive, .appName, "GoLand")
        add("Coding", .veryProductive, .appName, "RubyMine")
        add("Coding", .veryProductive, .appName, "Android Studio")
        add("Coding", .veryProductive, .bundleID, "com.github.atom")
        add("Coding", .veryProductive, .appName, "Nova")
        add("Coding", .veryProductive, .appName, "BBEdit")
        add("Coding", .veryProductive, .appName, "TextMate")
        add("Coding", .veryProductive, .appName, "Vim")
        add("Coding", .veryProductive, .appName, "Neovim")
        add("Coding", .veryProductive, .appName, "Emacs")
        add("Coding", .veryProductive, .appName, "Zed")

        // ── Terminal (+2) ──
        add("Terminal", .veryProductive, .bundleID, "com.apple.Terminal")
        add("Terminal", .veryProductive, .bundleID, "com.googlecode.iterm2")
        add("Terminal", .veryProductive, .appName, "iTerm")
        add("Terminal", .veryProductive, .appName, "Alacritty")
        add("Terminal", .veryProductive, .appName, "kitty")
        add("Terminal", .veryProductive, .appName, "Warp")
        add("Terminal", .veryProductive, .appName, "Hyper")

        // ── Design (+2) ──
        add("Design", .veryProductive, .appName, "Figma")
        add("Design", .veryProductive, .appName, "Sketch")
        add("Design", .veryProductive, .appName, "Photoshop")
        add("Design", .veryProductive, .appName, "Illustrator")
        add("Design", .veryProductive, .appName, "Blender")
        add("Design", .veryProductive, .appName, "Affinity Designer")
        add("Design", .veryProductive, .appName, "Affinity Photo")
        add("Design", .veryProductive, .appName, "Canva")
        add("Design", .veryProductive, .appName, "InDesign")
        add("Design", .veryProductive, .appName, "Pixelmator")
        add("Design", .veryProductive, .appName, "GIMP")

        // ── Writing (+1) ──
        add("Writing", .productive, .bundleID, "com.apple.iWork.Pages")
        add("Writing", .productive, .appName, "Microsoft Word")
        add("Writing", .productive, .appName, "Google Docs")
        add("Writing", .productive, .appName, "Notion")
        add("Writing", .productive, .bundleID, "md.obsidian")
        add("Writing", .productive, .appName, "Bear")
        add("Writing", .productive, .appName, "Ulysses")
        add("Writing", .productive, .appName, "Scrivener")
        add("Writing", .productive, .appName, "iA Writer")
        add("Writing", .productive, .appName, "Craft")
        add("Writing", .productive, .appName, "Typora")

        // ── Productivity Tools (+1) ──
        add("Productivity", .productive, .bundleID, "com.apple.iCal")
        add("Productivity", .productive, .bundleID, "com.apple.reminders")
        add("Productivity", .productive, .bundleID, "com.apple.Notes")
        add("Productivity", .productive, .appName, "Todoist")
        add("Productivity", .productive, .appName, "Things")
        add("Productivity", .productive, .appName, "OmniFocus")
        add("Productivity", .productive, .appName, "Linear")
        add("Productivity", .productive, .appName, "Jira")
        add("Productivity", .productive, .appName, "Asana")
        add("Productivity", .productive, .appName, "Trello")
        add("Productivity", .productive, .appName, "ClickUp")
        add("Productivity", .productive, .bundleID, "com.cruce.taskgo")

        // ── Spreadsheets / Data (+1) ──
        add("Spreadsheets", .productive, .appName, "Numbers")
        add("Spreadsheets", .productive, .appName, "Microsoft Excel")
        add("Spreadsheets", .productive, .appName, "Google Sheets")
        add("Spreadsheets", .productive, .bundleID, "com.apple.iWork.Keynote")

        // ── Reference (+1) ──
        add("Reference", .productive, .domain, "stackoverflow.com")
        add("Reference", .productive, .domain, "developer.apple.com")
        add("Reference", .productive, .domain, "github.com")
        add("Reference", .productive, .domain, "gitlab.com")
        add("Reference", .productive, .domain, "docs.swift.org")
        add("Reference", .productive, .domain, "developer.mozilla.org")
        add("Reference", .productive, .domain, "wikipedia.org")
        add("Reference", .productive, .domain, "medium.com")
        add("Reference", .productive, .domain, "dev.to")
        add("Reference", .productive, .domain, "arxiv.org")

        // ── Communication (0 Neutral) ──
        add("Communication", .neutral, .bundleID, "com.tinyspeck.slackmacgap")
        add("Communication", .neutral, .appName, "Slack")
        add("Communication", .neutral, .appName, "Discord")
        add("Communication", .neutral, .bundleID, "com.microsoft.teams2")
        add("Communication", .neutral, .appName, "Microsoft Teams")
        add("Communication", .neutral, .bundleID, "com.apple.MobileSMS")
        add("Communication", .neutral, .appName, "Messages")
        add("Communication", .neutral, .appName, "Telegram")
        add("Communication", .neutral, .appName, "WhatsApp")
        add("Communication", .neutral, .appName, "Signal")
        add("Communication", .neutral, .bundleID, "com.apple.mail")
        add("Communication", .neutral, .appName, "Gmail")
        add("Communication", .neutral, .appName, "Outlook")
        add("Communication", .neutral, .appName, "Spark")

        // ── Video Calls (0 Neutral) ──
        add("Meetings", .neutral, .appName, "Zoom")
        add("Meetings", .neutral, .appName, "Google Meet")
        add("Meetings", .neutral, .bundleID, "com.apple.FaceTime")
        add("Meetings", .neutral, .appName, "Webex")
        add("Meetings", .neutral, .appName, "Loom")

        // ── System (0 Neutral) ──
        add("System", .neutral, .bundleID, "com.apple.finder")
        add("System", .neutral, .bundleID, "com.apple.systempreferences")
        add("System", .neutral, .bundleID, "com.apple.SystemPreferences")
        add("System", .neutral, .appName, "System Settings")
        add("System", .neutral, .appName, "Activity Monitor")
        add("System", .neutral, .bundleID, "com.apple.Preview")
        add("System", .neutral, .appName, "Archive Utility")

        // ── News (-1) ──
        add("News", .distracting, .domain, "news.ycombinator.com")
        add("News", .distracting, .domain, "cnn.com")
        add("News", .distracting, .domain, "bbc.com")
        add("News", .distracting, .domain, "foxnews.com")
        add("News", .distracting, .domain, "nytimes.com")
        add("News", .distracting, .bundleID, "com.apple.news")

        // ── Shopping (-1) ──
        add("Shopping", .distracting, .domain, "amazon.com")
        add("Shopping", .distracting, .domain, "ebay.com")
        add("Shopping", .distracting, .domain, "etsy.com")
        add("Shopping", .distracting, .domain, "walmart.com")
        add("Shopping", .distracting, .domain, "target.com")

        // ── Social Media (-2) ──
        add("Social Media", .veryDistracting, .domain, "twitter.com")
        add("Social Media", .veryDistracting, .domain, "x.com")
        add("Social Media", .veryDistracting, .domain, "instagram.com")
        add("Social Media", .veryDistracting, .domain, "facebook.com")
        add("Social Media", .veryDistracting, .domain, "tiktok.com")
        add("Social Media", .veryDistracting, .domain, "reddit.com")
        add("Social Media", .veryDistracting, .domain, "snapchat.com")
        add("Social Media", .veryDistracting, .domain, "threads.net")
        add("Social Media", .veryDistracting, .domain, "tumblr.com")
        add("Social Media", .veryDistracting, .domain, "pinterest.com")

        // ── Entertainment (-2) ──
        add("Entertainment", .veryDistracting, .domain, "youtube.com")
        add("Entertainment", .veryDistracting, .domain, "netflix.com")
        add("Entertainment", .veryDistracting, .domain, "twitch.tv")
        add("Entertainment", .veryDistracting, .domain, "disneyplus.com")
        add("Entertainment", .veryDistracting, .domain, "hulu.com")
        add("Entertainment", .veryDistracting, .domain, "hbomax.com")
        add("Entertainment", .veryDistracting, .domain, "primevideo.com")
        add("Entertainment", .veryDistracting, .bundleID, "com.netflix.Netflix")
        add("Entertainment", .veryDistracting, .bundleID, "com.apple.TV")
        add("Entertainment", .veryDistracting, .bundleID, "tv.twitch.desktop")

        // ── Gaming (-2) ──
        add("Gaming", .veryDistracting, .bundleID, "com.valvesoftware.steam")
        add("Gaming", .veryDistracting, .appName, "Steam")
        add("Gaming", .veryDistracting, .bundleID, "com.epicgames.EpicGamesLauncher")

        // ── Music (Neutral — background audio doesn't mean distraction) ──
        add("Music", .neutral, .bundleID, "com.spotify.client")
        add("Music", .neutral, .bundleID, "com.apple.Music")
        add("Music", .neutral, .bundleID, "com.apple.iTunes")

        return rules
    }
}
