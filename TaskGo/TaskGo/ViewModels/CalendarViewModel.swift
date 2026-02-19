import Foundation
import Combine

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var todayEvents: [CalendarEvent] = []
    @Published var hasAccess = false
    @Published var selectedDate: Date = Date()

    private let calendarService = CalendarService.shared
    private var observer: NSObjectProtocol?

    func checkAccess() {
        hasAccess = calendarService.hasAccess
        if hasAccess {
            refreshEvents()
            startMonitoring()
        }
    }

    func requestAccess() async {
        let granted = await calendarService.requestAccess()
        hasAccess = granted
        if granted {
            refreshEvents()
            startMonitoring()
            scheduleCalendarAlerts()
        }
    }

    func refreshEvents() {
        todayEvents = calendarService.fetchEvents(for: selectedDate)
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        refreshEvents()
    }

    private func startMonitoring() {
        observer = calendarService.startMonitoring { [weak self] in
            Task { @MainActor in
                self?.refreshEvents()
                self?.scheduleCalendarAlerts()
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
    }
}
