import Foundation
import Combine

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var timedEvents: [CalendarEvent] = []
    @Published var allDayEvents: [CalendarEvent] = []
    @Published var hasAccess = false
    @Published var selectedDate: Date = Date()
    @Published var currentTime: Date = Date()

    private let calendarService = CalendarService.shared
    private var observer: NSObjectProtocol?
    private var refreshTimer: Timer?
    private var clockTimer: Timer?

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var todayEvents: [CalendarEvent] {
        timedEvents + allDayEvents
    }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    func checkAccess() {
        hasAccess = calendarService.hasAccess
        if hasAccess {
            loadEvents()
            startMonitoring()
            startPeriodicRefresh()
            startClockTimer()
        }
    }

    func requestAccess() async {
        let granted = await calendarService.requestAccess()
        hasAccess = granted
        if granted {
            loadEvents()
            startMonitoring()
            startPeriodicRefresh()
            startClockTimer()
            scheduleCalendarAlerts()
        }
    }

    func loadEvents() {
        let all = calendarService.fetchEvents(for: selectedDate)
        timedEvents = all.filter { !$0.isAllDay }
        allDayEvents = all.filter { $0.isAllDay }
    }

    func forceRefresh() {
        calendarService.resetStore()
        loadEvents()
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        loadEvents()
    }

    func goToNextDay() {
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectDate(next)
    }

    func goToPreviousDay() {
        guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectDate(prev)
    }

    func goToToday() {
        selectDate(Date())
    }

    private func startMonitoring() {
        observer = calendarService.startMonitoring { [weak self] in
            Task { @MainActor in
                self?.loadEvents()
                self?.scheduleCalendarAlerts()
            }
        }
    }

    private func startPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.loadEvents()
            }
        }
    }

    private func startClockTimer() {
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = Date()
            }
        }
    }

    private func scheduleCalendarAlerts() {
        let events = calendarService.fetchTodayEvents()
        for event in events {
            NotificationScheduler.shared.scheduleCalendarAlert(event)
        }
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        refreshTimer?.invalidate()
        clockTimer?.invalidate()
    }
}
