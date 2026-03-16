import Foundation
import Combine
import SwiftUI
import EventKit

enum CalendarViewMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
}

struct WritableCalendar: Identifiable {
    let id: String
    let title: String
    let color: Color
}

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var viewMode: CalendarViewMode = .week
    @Published var timedEvents: [CalendarEvent] = []
    @Published var allDayEvents: [CalendarEvent] = []
    @Published var weekDates: [Date] = []
    @Published var weekTimedEvents: [Date: [CalendarEvent]] = [:]
    @Published var weekAllDayEvents: [Date: [CalendarEvent]] = [:]
    @Published var writableCalendars: [WritableCalendar] = []
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
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: selectedDate)
    }

    var weekLabel: String {
        guard let first = weekDates.first, let last = weekDates.last else { return "" }
        let cal = Calendar.current
        if cal.component(.month, from: first) == cal.component(.month, from: last) {
            let mFmt = DateFormatter()
            mFmt.dateFormat = "MMM d"
            let dFmt = DateFormatter()
            dFmt.dateFormat = "d"
            return "\(mFmt.string(from: first)) – \(dFmt.string(from: last))"
        } else {
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            return "\(fmt.string(from: first)) – \(fmt.string(from: last))"
        }
    }

    var navigationLabel: String {
        viewMode == .day ? dateLabel : weekLabel
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
        loadWeekEvents()
        loadWritableCalendars()
    }

    func loadWeekEvents() {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: selectedDate)
        guard let startOfWeek = cal.date(byAdding: .day, value: -(weekday - 1), to: cal.startOfDay(for: selectedDate)) else { return }

        weekDates = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }

        var timed: [Date: [CalendarEvent]] = [:]
        var allDay: [Date: [CalendarEvent]] = [:]

        for date in weekDates {
            let events = calendarService.fetchEvents(for: date)
            let key = cal.startOfDay(for: date)
            timed[key] = events.filter { !$0.isAllDay }
            allDay[key] = events.filter { $0.isAllDay }
        }

        weekTimedEvents = timed
        weekAllDayEvents = allDay
    }

    func loadWritableCalendars() {
        writableCalendars = calendarService.getWritableCalendars().map { cal in
            WritableCalendar(
                id: cal.calendarIdentifier,
                title: cal.title,
                color: cal.cgColor != nil ? Color(cgColor: cal.cgColor!) : .blue
            )
        }
    }

    func forceRefresh() {
        calendarService.resetStore()
        loadEvents()
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        loadEvents()
    }

    func goToNext() {
        let days = viewMode == .week ? 7 : 1
        guard let next = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectDate(next)
    }

    func goToPrevious() {
        let days = viewMode == .week ? 7 : 1
        guard let prev = Calendar.current.date(byAdding: .day, value: -days, to: selectedDate) else { return }
        selectDate(prev)
    }

    func goToToday() {
        selectDate(Date())
    }

    func goToNextDay() { goToNext() }
    func goToPreviousDay() { goToPrevious() }

    func createEvent(title: String, startDate: Date, endDate: Date, calendarId: String) throws {
        _ = try calendarService.createEvent(title: title, startDate: startDate, endDate: endDate, calendarIdentifier: calendarId)
        loadEvents()
    }

    func deleteEvent(_ event: CalendarEvent) throws {
        try calendarService.deleteEvent(identifier: event.id)
        loadEvents()
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
