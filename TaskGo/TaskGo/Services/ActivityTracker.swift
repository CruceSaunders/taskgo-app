import Foundation
import AppKit
import IOKit
import IOKit.hid
import FirebaseAuth

/// Continuously tracks keyboard, mouse, scroll, and movement events for the Activity tab.
/// Runs from app launch to app quit. Stores per-minute data locally and syncs to Firestore.
class ActivityTracker: ObservableObject {
    static let shared = ActivityTracker()

    @Published var isTracking = false
    @Published var hasPermission = false
    @Published var todayData: ActivityDay

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var minuteTimer: Timer?
    private var flushTimer: Timer?
    private var permissionCheckTimer: Timer?

    private var currentKeyboard: Int = 0
    private var currentClicks: Int = 0
    private var currentScrolls: Int = 0
    private var currentMovement: Int = 0
    private var lastMovementTime: Date = .distantPast

    private let movementDebounceInterval: TimeInterval = 1.0

    private let localStorageDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".taskgo")
            .appendingPathComponent("activity")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {
        todayData = ActivityDay(date: Calendar.current.startOfDay(for: Date()))
        loadTodayFromDisk()
    }

    // MARK: - Permission

    func checkPermission() {
        let testTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        )
        if let tap = testTap {
            hasPermission = true
            CFMachPortInvalidate(tap)
        } else {
            hasPermission = false
        }
    }

    func requestPermission() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Start / Stop

    func start() {
        guard !isTracking else { return }

        rolloverDayIfNeeded()
        checkPermission()

        guard hasPermission else {
            print("[ActivityTracker] No Input Monitoring permission, starting poll...")
            startPermissionPolling()
            return
        }

        if startCGEventTapTracking() {
            isTracking = true
            print("[ActivityTracker] Tracking started successfully")
            startMinuteTimer()
            startFlushTimer()
        } else {
            print("[ActivityTracker] Failed to create CGEvent tap")
            startPermissionPolling()
        }
    }

    func stop() {
        guard isTracking else { return }

        finalizeCurrentMinute()
        flushToDisk()
        flushToFirestore()

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }

        minuteTimer?.invalidate()
        minuteTimer = nil
        flushTimer?.invalidate()
        flushTimer = nil
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil

        isTracking = false
    }

    // MARK: - CGEvent Tap

    private func startCGEventTapTracking() -> Bool {
        let eventMask: CGEventMask = (
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue)
        )

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, eventType, event, userInfo in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let tracker = Unmanaged<ActivityTracker>.fromOpaque(userInfo).takeUnretainedValue()

                switch eventType {
                case .keyDown:
                    DispatchQueue.main.async { tracker.currentKeyboard += 1 }
                    NotificationCenter.default.post(name: .activityDetected, object: nil)
                case .leftMouseDown, .rightMouseDown:
                    DispatchQueue.main.async { tracker.currentClicks += 1 }
                    NotificationCenter.default.post(name: .activityDetected, object: nil)
                case .scrollWheel:
                    DispatchQueue.main.async { tracker.currentScrolls += 1 }
                    NotificationCenter.default.post(name: .activityDetected, object: nil)
                case .mouseMoved:
                    DispatchQueue.main.async { tracker.recordMouseMovement() }
                default:
                    break
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = tap else { return false }

        self.eventTap = eventTap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        self.runLoopSource = source

        hasPermission = true
        return true
    }

    private func recordMouseMovement() {
        let now = Date()
        if now.timeIntervalSince(lastMovementTime) >= movementDebounceInterval {
            currentMovement += 1
            lastMovementTime = now
        }
    }

    // MARK: - Timers

    private func startMinuteTimer() {
        minuteTimer?.invalidate()
        minuteTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.onMinuteTick()
        }
        // Fire once immediately after a short delay so first data shows up quickly
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.finalizeCurrentMinute()
        }
    }

    private func startFlushTimer() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.flushToDisk()
            self?.flushToFirestore()
        }
    }

    private func startPermissionPolling() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.checkPermission()
            if self.hasPermission && !self.isTracking {
                self.permissionCheckTimer?.invalidate()
                self.permissionCheckTimer = nil
                self.start()
            }
        }
    }

    private func onMinuteTick() {
        rolloverDayIfNeeded()
        finalizeCurrentMinute()
    }

    // MARK: - Minute Finalization

    private func finalizeCurrentMinute() {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let min = calendar.component(.minute, from: now)
        let minuteOfDay = hour * 60 + min

        let kb = currentKeyboard
        let cl = currentClicks
        let sc = currentScrolls
        let mv = currentMovement

        currentKeyboard = 0
        currentClicks = 0
        currentScrolls = 0
        currentMovement = 0

        let hasActiveInput = kb > 0 || cl > 0
        let hasEngagedInput = sc > 0 || mv > 0

        guard hasActiveInput || hasEngagedInput else { return }

        let state: ActivityState
        if hasActiveInput {
            state = .active
        } else {
            state = .engaged
        }

        let entry = MinuteEntry(
            minute: minuteOfDay,
            keyboard: kb,
            clicks: cl,
            scrolls: sc,
            movement: mv,
            state: state
        )

        todayData.addMinuteEntry(entry)

        if todayData.firstActivity == nil {
            todayData.firstActivity = now
        }
        todayData.lastActivity = now

        objectWillChange.send()
    }

    // MARK: - Screen Lock Detection

    private func isScreenLocked() -> Bool {
        guard let sessionDict = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return true
        }
        if let locked = sessionDict["CGSSessionScreenIsLocked"] as? Bool, locked {
            return true
        }
        return false
    }

    // MARK: - Day Rollover

    private func rolloverDayIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        let dataDay = Calendar.current.startOfDay(for: todayData.date)

        if today != dataDay {
            flushToDisk()
            flushToFirestore()
            todayData = ActivityDay(date: today)
            loadTodayFromDisk()
        }
    }

    // MARK: - Local Persistence

    private func fileURL(for date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let name = formatter.string(from: date)
        return localStorageDir.appendingPathComponent("\(name).json")
    }

    private func loadTodayFromDisk() {
        let url = fileURL(for: todayData.date)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(ActivityDay.self, from: data)
            todayData = decoded
        } catch {
            print("[ActivityTracker] Failed to load local data: \(error)")
        }
    }

    func flushToDisk() {
        let url = fileURL(for: todayData.date)
        do {
            let data = try JSONEncoder().encode(todayData)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[ActivityTracker] Failed to save local data: \(error)")
        }
    }

    func flushToFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let dateString = todayData.dateString

        Task {
            do {
                try await FirestoreService.shared.saveActivityDay(todayData, userId: userId, dateString: dateString)
            } catch {
                print("[ActivityTracker] Firestore flush failed: \(error)")
            }
        }
    }

    func loadDay(date: Date) -> ActivityDay? {
        let url = fileURL(for: date)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ActivityDay.self, from: data)
        } catch {
            return nil
        }
    }

    func cleanLocalFilesOlderThan(days: Int = 365) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let files = try? FileManager.default.contentsOfDirectory(at: localStorageDir, includingPropertiesForKeys: nil) else { return }

        for file in files where file.pathExtension == "json" {
            let name = file.deletingPathExtension().lastPathComponent
            if let fileDate = formatter.date(from: name), fileDate < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
