import Foundation
import Combine

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var todayEvents: [CalendarEvent] = []
    @Published var hasAccess = false
    @Published var selectedDate: Date = Date()

    private let calendarService = CalendarService.shared
    private var observer: NSObjectProtocol?
    private var refreshTimer: Timer?

    func checkAccess() {
        hasAccess = calendarService.hasAccess
        if hasAccess {
            refreshEvents()
            startMonitoring()
            startPeriodicRefresh()
        }
    }

    func requestAccess() async {
        let granted = await calendarService.requestAccess()
        hasAccess = granted
        if granted {
            refreshEvents()
            startMonitoring()
            startPeriodicRefresh()
            scheduleCalendarAlerts()
        }
    }

    func refreshEvents() {
        selectedDate = Date()
        calendarService.resetStore()
        todayEvents = calendarService.fetchEvents(for: selectedDate)
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        calendarService.resetStore()
        todayEvents = calendarService.fetchEvents(for: date)
    }

    private func startMonitoring() {
        observer = calendarService.startMonitoring { [weak self] in
            Task { @MainActor in
                self?.refreshEvents()
                self?.scheduleCalendarAlerts()
            }
        }
    }

    private func startPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshEvents()
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
    }
}
