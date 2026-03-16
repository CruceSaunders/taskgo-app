import Foundation
import AppKit
import IOKit
import IOKit.hid
import FirebaseAuth
/// Continuously tracks keyboard, mouse, scroll, and movement events for the Activity tab.
/// Tries CGEvent tap first, falls back to NSEvent global monitors.
class ActivityTracker: ObservableObject {
    static let shared = ActivityTracker()

    @Published var isTracking = false
    @Published var hasPermission = false
    @Published var todayData: ActivityDay

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var minuteTimer: Timer?
    private var flushTimer: Timer?
    private var retryTimer: Timer?

    private var keyboardMonitor: Any?
    private var mouseClickMonitor: Any?
    private var scrollMonitor: Any?
    private var mouseMoveMonitor: Any?

    private var currentKeyboard: Int = 0
    private var currentClicks: Int = 0
    private var currentScrolls: Int = 0
    private var currentMovement: Int = 0
    private var lastMovementTime: Date = .distantPast
    private var totalEventsReceived: Int = 0

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
        writeDiag("ActivityTracker init at \(Date())")
    }

    private func writeDiag(_ message: String) {
        let path = localStorageDir.appendingPathComponent("diag.log")
        let line = "[\(Date())] \(message)\n"
        if let handle = try? FileHandle(forWritingTo: path) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8) ?? Data())
            handle.closeFile()
        } else {
            try? line.write(to: path, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Permission

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Start / Stop

    func start() {
        guard !isTracking else { return }
        rolloverDayIfNeeded()
        writeDiag("start() called at \(Date()), AXTrusted=\(AXIsProcessTrusted())")

        if startNSEventMonitoring() {
            hasPermission = true
            isTracking = true
            writeDiag("NSEvent global monitor tracking STARTED")
        } else if startCGEventTapTracking() {
            hasPermission = true
            isTracking = true
            writeDiag("CGEvent tap tracking STARTED")
        } else {
            hasPermission = false
            writeDiag("ALL monitoring methods FAILED, retrying in 15s")
            startRetryTimer()
            return
        }

        retryTimer?.invalidate()
        retryTimer = nil
        startMinuteTimer()
        startFlushTimer()

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self = self, self.isTracking else { return }
            if self.totalEventsReceived == 0 {
                self.writeDiag("WARN: 0 events after 12s. Permission may be stale. AXTrusted=\(AXIsProcessTrusted())")
                self.hasPermission = false
            }
        }
    }

    func stop() {
        finalizeCurrentMinute()
        flushToDisk()
        flushToFirestore()
        teardownMonitoring()
        minuteTimer?.invalidate()
        minuteTimer = nil
        flushTimer?.invalidate()
        flushTimer = nil
        retryTimer?.invalidate()
        retryTimer = nil
        isTracking = false
    }

    private func teardownMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let m = keyboardMonitor { NSEvent.removeMonitor(m); keyboardMonitor = nil }
        if let m = mouseClickMonitor { NSEvent.removeMonitor(m); mouseClickMonitor = nil }
        if let m = scrollMonitor { NSEvent.removeMonitor(m); scrollMonitor = nil }
        if let m = mouseMoveMonitor { NSEvent.removeMonitor(m); mouseMoveMonitor = nil }
    }

    // MARK: - CGEvent Tap (Primary)

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

                tracker.totalEventsReceived += 1
                switch eventType {
                case .keyDown:
                    tracker.currentKeyboard += 1
                    NotificationCenter.default.post(name: .activityDetected, object: nil)
                case .leftMouseDown, .rightMouseDown:
                    tracker.currentClicks += 1
                    NotificationCenter.default.post(name: .activityDetected, object: nil)
                case .scrollWheel:
                    tracker.currentScrolls += 1
                case .mouseMoved:
                    tracker.recordMouseMovement()
                default:
                    break
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = tap else {
            writeDiag("CGEvent.tapCreate returned nil")
            return false
        }

        self.eventTap = eventTap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        self.runLoopSource = source
        return true
    }

    // MARK: - NSEvent Global Monitor (Fallback)

    private func startNSEventMonitoring() -> Bool {
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] _ in
            self?.currentKeyboard += 1
            NotificationCenter.default.post(name: .activityDetected, object: nil)
        }

        mouseClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.currentClicks += 1
            NotificationCenter.default.post(name: .activityDetected, object: nil)
        }

        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] _ in
            self?.currentScrolls += 1
        }

        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.recordMouseMovement()
        }

        let anyWorked = keyboardMonitor != nil || mouseClickMonitor != nil
        writeDiag("NSEvent monitors: kb=\(keyboardMonitor != nil) click=\(mouseClickMonitor != nil) scroll=\(scrollMonitor != nil) move=\(mouseMoveMonitor != nil)")
        return anyWorked
    }

    // MARK: - Helpers

    private func recordMouseMovement() {
        let now = Date()
        if now.timeIntervalSince(lastMovementTime) >= movementDebounceInterval {
            currentMovement += 1
            lastMovementTime = now
        }
    }

    private func startRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let self = self, !self.isTracking else { return }
            self.writeDiag("Retrying start...")
            self.start()
        }
    }

    // MARK: - Timers

    private func startMinuteTimer() {
        minuteTimer?.invalidate()
        minuteTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.onMinuteTick()
        }
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

        writeDiag("finalize min=\(minuteOfDay) kb=\(kb) cl=\(cl) sc=\(sc) mv=\(mv) totalEvents=\(totalEventsReceived) tracking=\(isTracking)")

        guard hasActiveInput || hasEngagedInput else { return }

        let state: ActivityState = hasActiveInput ? .active : .engaged

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
            NSLog("[ActivityTracker] Failed to load local data: %@", error.localizedDescription)
        }
    }

    func flushToDisk() {
        let url = fileURL(for: todayData.date)
        do {
            let data = try JSONEncoder().encode(todayData)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("[ActivityTracker] Failed to save local data: %@", error.localizedDescription)
        }
    }

    func flushToFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let dateString = todayData.dateString

        Task {
            do {
                try await FirestoreService.shared.saveActivityDay(todayData, userId: userId, dateString: dateString)
            } catch {
                NSLog("[ActivityTracker] Firestore flush failed: %@", error.localizedDescription)
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
