import Foundation
import AppKit
import IOKit
import IOKit.hid
import CoreAudio
import FirebaseAuth

class ActivityTracker: ObservableObject {
    static let shared = ActivityTracker()

    // MARK: - Published State

    @Published var isTracking = false
    @Published var hasPermission = false
    @Published var eventsAreFlowing = false
    @Published var todayData: ActivityDay
    @Published var permissionState: PermissionState = .unknown
    @Published var sttAppsDetected: [String] = []
    @Published var keyboardHealthy = true

    enum PermissionState: String {
        case unknown, checking, granted, denied
    }

    // MARK: - Event Taps & Monitors

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var minuteTimer: Timer?
    private var flushTimer: Timer?
    private var retryTimer: Timer?
    private var sttCheckTimer: Timer?
    private var micSampleTimer: Timer?
    private var hidManager: IOHIDManager?
    private var keyboardPollTimer: Timer?

    private var keyboardMonitor: Any?
    private var mouseClickMonitor: Any?
    private var scrollMonitor: Any?
    private var mouseMoveMonitor: Any?
    private var localKeyboardMonitor: Any?
    private var localMouseClickMonitor: Any?

    // MARK: - Per-Minute Accumulators

    private var currentKeyboard: Int = 0
    private var currentClicks: Int = 0
    private var currentScrolls: Int = 0
    private var currentMovement: Int = 0
    private var currentDictation: Int = 0
    private var currentMicSeconds: Int = 0

    // MARK: - Per-Event-Type Health Counters (lifetime since start)

    private(set) var keyboardEventsReceived: Int = 0
    private(set) var clickEventsReceived: Int = 0
    private(set) var scrollEventsReceived: Int = 0
    private(set) var moveEventsReceived: Int = 0
    private var totalEventsReceived: Int = 0

    // MARK: - HID Keyboard State

    private var hidKeyboardActive = false
    private var lastHIDKeyboardTime: Date = .distantPast
    private var previousKeyStates: Set<CGKeyCode> = []
    private var keyboardPollActive = false

    // MARK: - Debounce State

    private var lastMovementTime: Date = .distantPast
    private var lastScrollTime: Date = .distantPast

    // MARK: - Constants

    private let movementDebounceInterval: TimeInterval = 1.0
    private let scrollDebounceInterval: TimeInterval = 0.3
    private let micSampleInterval: TimeInterval = 5.0

    private let knownSTTBundleIDPrefixes: [String] = [
        "ai.wispr",
        "com.wispr",
        "com.nuance.dragon",
        "com.talonvoice",
        "ai.otter"
    ]

    private let knownSTTAppNameSubstrings: [String] = [
        "Wispr", "Dragon", "Talon", "Otter", "Dictation"
    ]

    // MARK: - Storage

    let localStorageDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".taskgo")
            .appendingPathComponent("activity")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private lazy var diagLogURL: URL = {
        localStorageDir.appendingPathComponent("diag.log")
    }()

    // MARK: - Init

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

        diagLog("ActivityTracker initialized")
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
        permissionState = .checking

        let nsEventOK = startNSEventMonitoring()
        startLocalEventMonitoring()

        var anyMonitorStarted = nsEventOK

        if !nsEventOK {
            if startCGEventTapTracking() {
                anyMonitorStarted = true
                diagLog("CGEvent tap started (NSEvent unavailable)")
            }
        } else {
            diagLog("NSEvent monitors started")
        }

        if anyMonitorStarted {
            hasPermission = true
            permissionState = .granted
            isTracking = true
        } else {
            hasPermission = false
            permissionState = .denied
            diagLog("No event monitoring available — retrying in 15s")
            startRetryTimer()
            return
        }

        startHIDKeyboardMonitoring()

        retryTimer?.invalidate()
        retryTimer = nil
        startMinuteTimer()
        startFlushTimer()
        startSTTMonitor()
        startMicSampler()

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.verifyEventFlow()
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
        sttCheckTimer?.invalidate()
        sttCheckTimer = nil
        micSampleTimer?.invalidate()
        micSampleTimer = nil
        stopHIDKeyboardMonitoring()
        stopKeyboardPolling()
        isTracking = false
        diagLog("ActivityTracker stopped")
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
        if let m = localKeyboardMonitor { NSEvent.removeMonitor(m); localKeyboardMonitor = nil }
        if let m = localMouseClickMonitor { NSEvent.removeMonitor(m); localMouseClickMonitor = nil }
    }

    // MARK: - IOKit HID Keyboard Monitoring

    private func startHIDKeyboardMonitoring() {
        guard hidManager == nil else { return }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matchingDict: [[String: Any]] = [
            [kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
             kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard],
            [kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
             kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keypad]
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingDict as CFArray)

        let callback: IOHIDValueCallback = { context, _, _, value in
            guard let context = context else { return }
            let tracker = Unmanaged<ActivityTracker>.fromOpaque(context).takeUnretainedValue()

            let element = IOHIDValueGetElement(value)
            let usagePage = IOHIDElementGetUsagePage(element)
            let usage = IOHIDElementGetUsage(element)
            let intValue = IOHIDValueGetIntegerValue(value)

            guard usagePage == kHIDPage_KeyboardOrKeypad,
                  usage >= 4, usage <= 231,
                  intValue == 1 else { return }

            tracker.keyboardEventsReceived += 1
            tracker.currentKeyboard += 1
            tracker.totalEventsReceived += 1
            tracker.lastHIDKeyboardTime = Date()

            if !tracker.hidKeyboardActive {
                tracker.hidKeyboardActive = true
                tracker.diagLog("HID keyboard events flowing")
            }

            if !tracker.eventsAreFlowing {
                DispatchQueue.main.async { tracker.eventsAreFlowing = true }
            }
            NotificationCenter.default.post(name: .activityDetected, object: nil)
        }

        IOHIDManagerRegisterInputValueCallback(manager, callback, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        if openResult == kIOReturnSuccess {
            hidManager = manager
            diagLog("HID keyboard monitoring started")
        } else {
            diagLog("HID keyboard monitoring failed to open: \(openResult) — falling back to polling")
            startKeyboardPolling()
        }
    }

    private func stopHIDKeyboardMonitoring() {
        guard let manager = hidManager else { return }
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        hidManager = nil
    }

    // MARK: - Keyboard Polling Fallback (no permissions needed)

    private func startKeyboardPolling() {
        guard !keyboardPollActive else { return }
        keyboardPollTimer?.invalidate()
        keyboardPollTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.pollKeyboardState()
        }
        keyboardPollActive = true
        diagLog("Keyboard polling fallback started (0.4s interval)")
    }

    private func stopKeyboardPolling() {
        keyboardPollTimer?.invalidate()
        keyboardPollTimer = nil
        keyboardPollActive = false
    }

    private func pollKeyboardState() {
        var currentlyDown = Set<CGKeyCode>()
        for keyCode: CGKeyCode in 4...231 {
            if CGEventSource.keyState(.combinedSessionState, key: keyCode) {
                currentlyDown.insert(keyCode)
            }
        }

        let newPresses = currentlyDown.subtracting(previousKeyStates)
        previousKeyStates = currentlyDown

        if !newPresses.isEmpty {
            let count = newPresses.count
            keyboardEventsReceived += count
            currentKeyboard += count
            totalEventsReceived += count

            if !eventsAreFlowing {
                DispatchQueue.main.async { [weak self] in self?.eventsAreFlowing = true }
            }
            NotificationCenter.default.post(name: .activityDetected, object: nil)
        }
    }

    // MARK: - CGEvent Tap

    private func startCGEventTapTracking(eventMask customMask: CGEventMask? = nil) -> Bool {
        guard eventTap == nil else { return true }

        let eventMask: CGEventMask = customMask ?? (
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
                    tracker.keyboardEventsReceived += 1
                    tracker.currentKeyboard += 1
                    NotificationCenter.default.post(name: .activityDetected, object: nil)
                case .leftMouseDown, .rightMouseDown:
                    tracker.clickEventsReceived += 1
                    tracker.currentClicks += 1
                    NotificationCenter.default.post(name: .activityDetected, object: nil)
                case .scrollWheel:
                    tracker.recordScrollEvent()
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

    // MARK: - NSEvent Global Monitors

    private func startNSEventMonitoring() -> Bool {
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] _ in
            guard let self = self else { return }
            self.totalEventsReceived += 1
            self.keyboardEventsReceived += 1
            self.currentKeyboard += 1
            if !self.eventsAreFlowing {
                DispatchQueue.main.async { self.eventsAreFlowing = true }
            }
            NotificationCenter.default.post(name: .activityDetected, object: nil)
        }
        mouseClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            self.totalEventsReceived += 1
            self.clickEventsReceived += 1
            self.currentClicks += 1
            if !self.eventsAreFlowing {
                DispatchQueue.main.async { self.eventsAreFlowing = true }
            }
            NotificationCenter.default.post(name: .activityDetected, object: nil)
        }
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] _ in
            guard let self = self else { return }
            self.totalEventsReceived += 1
            self.recordScrollEvent()
        }
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            guard let self = self else { return }
            self.totalEventsReceived += 1
            self.recordMouseMovement()
        }
        return keyboardMonitor != nil || mouseClickMonitor != nil
    }

    // MARK: - NSEvent Local Monitors (captures in-app events)

    private func startLocalEventMonitoring() {
        localKeyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }
            self.totalEventsReceived += 1
            self.keyboardEventsReceived += 1
            self.currentKeyboard += 1
            if !self.eventsAreFlowing {
                DispatchQueue.main.async { self.eventsAreFlowing = true }
            }
            NotificationCenter.default.post(name: .activityDetected, object: nil)
            return event
        }
        localMouseClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            self.totalEventsReceived += 1
            self.clickEventsReceived += 1
            self.currentClicks += 1
            if !self.eventsAreFlowing {
                DispatchQueue.main.async { self.eventsAreFlowing = true }
            }
            NotificationCenter.default.post(name: .activityDetected, object: nil)
            return event
        }
    }

    // MARK: - Event Flow Verification

    private func verifyEventFlow() {
        guard isTracking else { return }

        let hasOtherEvents = clickEventsReceived > 0 || scrollEventsReceived > 0 || moveEventsReceived > 0

        if keyboardEventsReceived == 0 && hasOtherEvents {
            if hidKeyboardActive || keyboardPollActive {
                diagLog("NSEvent/CGEvent keyboard failed but fallback is catching keyboard events — healthy")
                keyboardHealthy = true
            } else {
                diagLog("Keyboard events not flowing via NSEvent or HID — starting polling fallback")
                keyboardHealthy = false
                startKeyboardPolling()
            }
        } else if totalEventsReceived == 0 {
            diagLog("No events received after 30s — permission likely denied")
            hasPermission = false
            permissionState = .denied
        } else {
            keyboardHealthy = true
            eventsAreFlowing = true
            diagLog("Event flow OK: kb=\(keyboardEventsReceived) click=\(clickEventsReceived) scroll=\(scrollEventsReceived) move=\(moveEventsReceived) hidKb=\(hidKeyboardActive)")
        }
    }

    // MARK: - Microphone Sampling (every 5 seconds)

    private func startMicSampler() {
        micSampleTimer?.invalidate()
        micSampleTimer = Timer.scheduledTimer(withTimeInterval: micSampleInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isMicrophoneInUse() {
                self.currentMicSeconds += Int(self.micSampleInterval)
            }
        }
    }

    // MARK: - Scroll Debounce

    private func recordScrollEvent() {
        let now = Date()
        if now.timeIntervalSince(lastScrollTime) >= scrollDebounceInterval {
            scrollEventsReceived += 1
            currentScrolls += 1
            lastScrollTime = now
            NotificationCenter.default.post(name: .activityDetected, object: nil)
        }
    }

    // MARK: - Mouse Movement

    private func recordMouseMovement() {
        let now = Date()
        if now.timeIntervalSince(lastMovementTime) >= movementDebounceInterval {
            moveEventsReceived += 1
            currentMovement += 1
            lastMovementTime = now
        }
    }

    // MARK: - STT Detection

    private func startSTTMonitor() {
        checkSTTApps()
        sttCheckTimer?.invalidate()
        sttCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkSTTApps()
        }
    }

    private func checkSTTApps() {
        let running = NSWorkspace.shared.runningApplications
        var matchedBundles = Set<String>()

        for app in running {
            let bundleID = app.bundleIdentifier ?? ""
            let name = app.localizedName ?? ""

            let matchesBundle = knownSTTBundleIDPrefixes.contains { bundleID.hasPrefix($0) }
            let matchesName = knownSTTAppNameSubstrings.contains { name.localizedCaseInsensitiveContains($0) }

            if matchesBundle || matchesName {
                let key = knownSTTBundleIDPrefixes.first { bundleID.hasPrefix($0) } ?? bundleID
                matchedBundles.insert(key)
            }
        }

        let detected = Array(matchedBundles)

        DispatchQueue.main.async { [weak self] in
            self?.sttAppsDetected = detected
        }
    }

    // MARK: - Retry Timer

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

        let calendar = Calendar.current
        let now = Date()
        guard let nextMinute = calendar.nextDate(
            after: now,
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime
        ) else {
            minuteTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.onMinuteTick()
            }
            return
        }

        let timer = Timer(fire: nextMinute, interval: 60, repeats: true) { [weak self] _ in
            self?.onMinuteTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        minuteTimer = timer
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
        let dc = currentDictation
        let micSecs = currentMicSeconds
        let micActive = micSecs >= 3 ? 1 : 0
        let speakingValue = micSecs

        currentKeyboard = 0
        currentClicks = 0
        currentScrolls = 0
        currentMovement = 0
        currentDictation = 0
        currentMicSeconds = 0

        guard kb > 0 || cl > 0 || sc > 0 || mv > 0 || dc > 0 || micActive > 0 else { return }

        let entry = MinuteEntry(
            minute: minuteOfDay,
            keyboard: kb,
            clicks: cl,
            scrolls: sc,
            movement: mv,
            dictation: speakingValue,
            meeting: micActive
        )

        todayData.addMinuteEntry(entry)

        if todayData.firstActivity == nil {
            todayData.firstActivity = now
        }
        todayData.lastActivity = now

        objectWillChange.send()
        flushToDisk()
    }

    // MARK: - Microphone Detection

    private func isMicrophoneInUse() -> Bool {
        var defaultDeviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &defaultDeviceID
        )
        guard status == noErr, defaultDeviceID != 0 else { return false }

        var isRunning: UInt32 = 0
        var runningSize = UInt32(MemoryLayout<UInt32>.size)
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let runStatus = AudioObjectGetPropertyData(
            defaultDeviceID,
            &runningAddress, 0, nil, &runningSize, &isRunning
        )
        return runStatus == noErr && isRunning != 0
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
        guard FileManager.default.fileExists(atPath: url.path) else {
            diagLog("No data file at \(url.lastPathComponent) — starting fresh")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            var decoded = try JSONDecoder().decode(ActivityDay.self, from: data)
            if decoded.id == nil {
                decoded.id = decoded.dateString
            }
            todayData = decoded
            diagLog("Loaded \(todayData.minuteData.count) minute entries from \(url.lastPathComponent)")
        } catch {
            diagLog("Failed to decode \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    func flushToDisk() {
        let url = fileURL(for: todayData.date)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(todayData)
            try data.write(to: url, options: .atomic)
        } catch {
            diagLog("flushToDisk FAILED: \(error.localizedDescription) — path: \(url.path)")
        }
    }

    func flushToFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let dateString = todayData.dateString
        let dayData = todayData

        Task {
            do {
                try await FirestoreService.shared.saveActivityDay(dayData, userId: userId, dateString: dateString)
            } catch {
                diagLog("flushToFirestore failed: \(error.localizedDescription)")
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

    // MARK: - Diagnostic Logging

    private func diagLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
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
}
