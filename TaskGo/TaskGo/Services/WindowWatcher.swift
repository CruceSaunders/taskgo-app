import Foundation
import AppKit
import ApplicationServices

class WindowWatcher: ObservableObject {
    static let shared = WindowWatcher()

    @Published var currentAppName: String = ""
    @Published var currentWindowTitle: String = ""
    @Published var currentDomain: String?
    @Published var currentCategory: String = "Other"
    @Published var currentProductivityLevel: ProductivityLevel = .neutral
    @Published var isIdle: Bool = false
    @Published var activeTaskName: String?

    private var pollTimer: Timer?
    private var idleCheckTimer: Timer?
    private var isRunning = false

    private var activeSegment: LiveSegment?
    private var completedSegments: [AppSegment] = []
    private let segmentLock = NSLock()

    private var lastInputTime: Date = Date()
    private var isScreenLocked = false

    private let pollInterval: TimeInterval = 5.0
    private let idleThresholdSeconds: TimeInterval = 300

    private let preferences: TrackingPreferences

    private struct LiveSegment {
        let bundleID: String
        let appName: String
        var windowTitle: String
        var domain: String?
        let category: String
        let productivityScore: Int
        var startTime: Date
        var accumulatedSeconds: Int
        var taskName: String?

        func toAppSegment() -> AppSegment {
            AppSegment(
                bundleID: bundleID,
                appName: appName,
                windowTitle: windowTitle,
                domain: domain,
                category: category,
                productivityScore: productivityScore,
                seconds: accumulatedSeconds,
                taskName: taskName
            )
        }
    }

    @Published var lastHarvestInfo: String = ""
    @Published var totalSegmentsToday: Int = 0
    @Published var totalSegmentSecondsToday: Int = 0

    private lazy var diagLogURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".taskgo").appendingPathComponent("activity")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("watcher-diag.log")
    }()

    private init() {
        preferences = TrackingPreferences.load()
        setupNotifications()
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastInputTime = Date()

        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(pollTimer!, forMode: .common)

        poll()
    }

    func stop() {
        isRunning = false
        pollTimer?.invalidate()
        pollTimer = nil
        idleCheckTimer?.invalidate()
        idleCheckTimer = nil
        finalizeActiveSegment()
    }

    // MARK: - Sleep / Wake / Lock

    private func setupNotifications() {
        let ws = NSWorkspace.shared.notificationCenter

        ws.addObserver(self, selector: #selector(handleSleep),
                       name: NSWorkspace.willSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(handleWake),
                       name: NSWorkspace.didWakeNotification, object: nil)
        ws.addObserver(self, selector: #selector(handleScreenLock),
                       name: NSWorkspace.screensDidSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(handleScreenUnlock),
                       name: NSWorkspace.screensDidWakeNotification, object: nil)

        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(handleScreenLock),
            name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(handleScreenUnlock),
            name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
    }

    @objc private func handleSleep() {
        finalizeActiveSegment()
        isScreenLocked = true
    }

    @objc private func handleWake() {
        isScreenLocked = false
        lastInputTime = Date()
    }

    @objc private func handleScreenLock() {
        finalizeActiveSegment()
        isScreenLocked = true
    }

    @objc private func handleScreenUnlock() {
        isScreenLocked = false
        lastInputTime = Date()
    }

    // MARK: - Activity Detection (called by ActivityTracker)

    func recordUserInput() {
        lastInputTime = Date()
        if isIdle {
            DispatchQueue.main.async { self.isIdle = false }
        }
    }

    // MARK: - Polling

    private func poll() {
        guard isRunning, !isScreenLocked else { return }

        let idleSeconds = Date().timeIntervalSince(lastInputTime)
        let wasIdle = isIdle
        let nowIdle = idleSeconds >= idleThresholdSeconds

        if nowIdle != wasIdle {
            DispatchQueue.main.async { self.isIdle = nowIdle }
        }

        if nowIdle {
            finalizeActiveSegment()
            return
        }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            finalizeActiveSegment()
            return
        }

        let bundleID = frontApp.bundleIdentifier ?? "unknown"
        let appName = frontApp.localizedName ?? "Unknown"
        let pid = frontApp.processIdentifier

        var windowTitle = ""
        if preferences.trackWindowTitles {
            windowTitle = getWindowTitle(pid: pid) ?? ""
        }

        var domain: String?
        if preferences.trackBrowserURLs, BrowserTracker.isBrowser(bundleID: bundleID) {
            if let urlInfo = BrowserTracker.shared.getCurrentURL(for: bundleID, appName: appName) {
                domain = urlInfo.domain
                if !urlInfo.pageTitle.isEmpty {
                    windowTitle = urlInfo.pageTitle
                }
            }
        }

        let result = CategoryEngine.shared.classify(
            bundleID: bundleID,
            appName: appName,
            windowTitle: windowTitle,
            domain: domain
        )

        DispatchQueue.main.async {
            self.currentAppName = appName
            self.currentWindowTitle = windowTitle
            self.currentDomain = domain
            self.currentCategory = result.category
            self.currentProductivityLevel = result.productivityLevel
        }

        segmentLock.lock()
        defer { segmentLock.unlock() }

        if var active = activeSegment,
           active.bundleID == bundleID,
           active.windowTitle == windowTitle,
           active.domain == domain {
            active.accumulatedSeconds += Int(pollInterval)
            activeSegment = active
            wDiagLog("[POLL] app=\(appName) category=\(result.category) score=\(result.productivityLevel.rawValue) action=EXTEND seconds=\(active.accumulatedSeconds)")
        } else {
            if let active = activeSegment {
                completedSegments.append(active.toAppSegment())
                wDiagLog("[SEGMENT] app=\(active.appName) seconds=\(active.accumulatedSeconds) category=\(active.category)")
            }
            activeSegment = LiveSegment(
                bundleID: bundleID,
                appName: appName,
                windowTitle: windowTitle,
                domain: domain,
                category: result.category,
                productivityScore: result.productivityLevel.rawValue,
                startTime: Date(),
                accumulatedSeconds: Int(pollInterval),
                taskName: activeTaskName
            )
            wDiagLog("[POLL] app=\(appName) category=\(result.category) score=\(result.productivityLevel.rawValue) action=NEW domain=\(domain ?? "nil")")
        }
    }

    // MARK: - Window Title (Accessibility API)

    private func getWindowTitle(pid: pid_t) -> String? {
        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?

        let windowResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard windowResult == .success, let window = focusedWindow else {
            return nil
        }

        var titleValue: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            kAXTitleAttribute as CFString,
            &titleValue
        )

        guard titleResult == .success, let title = titleValue as? String else {
            return nil
        }

        return title
    }

    // MARK: - Segment Management

    private func finalizeActiveSegment() {
        segmentLock.lock()
        defer { segmentLock.unlock() }

        if let active = activeSegment, active.accumulatedSeconds > 0 {
            completedSegments.append(active.toAppSegment())
        }
        activeSegment = nil
    }

    func harvestSegments() -> [AppSegment] {
        segmentLock.lock()
        defer { segmentLock.unlock() }

        var result = completedSegments

        if var active = activeSegment, active.accumulatedSeconds > 0 {
            result.append(active.toAppSegment())
            active.accumulatedSeconds = 0
            active.startTime = Date()
            activeSegment = active
        }

        completedSegments.removeAll()

        let totalSec = result.reduce(0) { $0 + $1.seconds }
        let activeInfo = activeSegment.map { "\($0.appName)(\($0.accumulatedSeconds)s)" } ?? "none"
        wDiagLog("[HARVEST] segments=\(result.count) totalSeconds=\(totalSec) activeSegment=\(activeInfo)")

        totalSegmentsToday += result.count
        totalSegmentSecondsToday += totalSec
        DispatchQueue.main.async {
            self.lastHarvestInfo = "\(result.count) segs, \(totalSec)s"
        }

        return result
    }

    // MARK: - Diagnostic Logging

    private func wDiagLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: diagLogURL.path) {
            if let handle = try? FileHandle(forWritingTo: diagLogURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: diagLogURL, options: .atomic)
        }
    }
}
