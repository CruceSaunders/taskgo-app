import Foundation
import AppKit
import IOKit
import IOKit.hid
import FirebaseAuth

/// Continuously tracks keyboard, mouse, scroll, and movement events for the Activity tab.
class ActivityTracker: ObservableObject {
    static let shared = ActivityTracker()

    @Published var isTracking = false
    @Published var hasPermission = false
    @Published var eventsAreFlowing = false
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

    let localStorageDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".taskgo")
            .appendingPathComponent("activity")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {
        todayData = ActivityDay(date: Calendar.current.startOfDay(for: Date()))
        loadTodayFromDisk()

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.finalizeCurrentMinute()
            self?.flushToDisk()
            self?.flushToFirestore()
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

        if startNSEventMonitoring() {
            hasPermission = true
            isTracking = true
        } else if startCGEventTapTracking() {
            hasPermission = true
            isTracking = true
        } else {
            hasPermission = false
            startRetryTimer()
            return
        }

        retryTimer?.invalidate()
        retryTimer = nil
        startMinuteTimer()
        startFlushTimer()

        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self, self.isTracking else { return }
            if self.totalEventsReceived > 0 {
                self.eventsAreFlowing = true
            } else {
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

                tracker.totalEventsReceived += 1
                if !tracker.eventsAreFlowing {
                    DispatchQueue.main.async { tracker.eventsAreFlowing = true }
                }
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

        guard let eventTap = tap else { return false }

        self.eventTap = eventTap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        self.runLoopSource = source
        return true
    }

    // MARK: - NSEvent Global Monitor

    private func startNSEventMonitoring() -> Bool {
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] _ in
            guard let self = self else { return }
            self.totalEventsReceived += 1
            self.currentKeyboard += 1
            if !self.eventsAreFlowing {
                DispatchQueue.main.async { self.eventsAreFlowing = true }
            }
            NotificationCenter.default.post(name: .activityDetected, object: nil)
        }
        mouseClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            self.totalEventsReceived += 1
            self.currentClicks += 1
            if !self.eventsAreFlowing {
                DispatchQueue.main.async { self.eventsAreFlowing = true }
            }
            NotificationCenter.default.post(name: .activityDetected, object: nil)
        }
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] _ in
            self?.totalEventsReceived += 1
            self?.currentScrolls += 1
        }
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.totalEventsReceived += 1
            self?.recordMouseMovement()
        }
        return keyboardMonitor != nil || mouseClickMonitor != nil
    }

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

        guard kb > 0 || cl > 0 || sc > 0 || mv > 0 else { return }

        let entry = MinuteEntry(
            minute: minuteOfDay,
            keyboard: kb,
            clicks: cl,
            scrolls: sc,
            movement: mv
        )

        todayData.addMinuteEntry(entry)

        if todayData.firstActivity == nil {
            todayData.firstActivity = now
        }
        todayData.lastActivity = now

        objectWillChange.send()
        flushToDisk()
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

    func fileURL(for date: Date) -> URL {
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
            var decoded = try JSONDecoder().decode(ActivityDay.self, from: data)
            if decoded.id == nil {
                decoded.id = decoded.dateString
            }
            todayData = decoded
        } catch {
            // corrupted file -- start fresh
        }
    }

    func flushToDisk() {
        let url = fileURL(for: todayData.date)
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(todayData)
            try data.write(to: url, options: .atomic)
        } catch {
            // silent fail
        }
    }

    func flushToFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let dateString = todayData.dateString
        let dayData = todayData

        Task {
            try? await FirestoreService.shared.saveActivityDay(dayData, userId: userId, dateString: dateString)
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
