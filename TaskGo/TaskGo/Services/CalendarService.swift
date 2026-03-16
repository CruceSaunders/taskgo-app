import EventKit
import SwiftUI
import Combine

class CalendarService: ObservableObject {
    static let shared = CalendarService()

    private let store = EKEventStore()
    @Published var hasAccess = false

    private init() {
        checkAccess()
    }

    private func checkAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        hasAccess = status == .fullAccess || status == .authorized
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            await MainActor.run { hasAccess = granted }
            return granted
        } catch {
            print("[Calendar] Access request error: \(error)")
            return false
        }
    }

    func resetStore() {
        store.reset()
    }

    func fetchEvents(for date: Date) -> [CalendarEvent] {
        guard hasAccess else { return [] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        return ekEvents
            .map { CalendarEvent(from: $0) }
            .sorted { $0.startDate < $1.startDate }
    }

    func fetchTodayEvents() -> [CalendarEvent] {
        fetchEvents(for: Date())
    }

    func fetchWeekEvents() -> [Date: [CalendarEvent]] {
        guard hasAccess else { return [:] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [Date: [CalendarEvent]] = [:]

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let events = fetchEvents(for: date)
            if !events.isEmpty {
                result[date] = events
            }
        }

        return result
    }

    func startMonitoring(onChange: @escaping () -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { _ in
            onChange()
        }
    }

    // MARK: - Write Capabilities

    func getWritableCalendars() -> [EKCalendar] {
        guard hasAccess else { return [] }
        return store.calendars(for: .event).filter { $0.allowsContentModifications }
    }

    func calendarTitle(for identifier: String) -> String? {
        guard hasAccess else { return nil }
        return store.calendars(for: .event).first { $0.calendarIdentifier == identifier }?.title
    }

    func createEvent(title: String, startDate: Date, endDate: Date, calendarIdentifier: String) throws -> String {
        guard hasAccess else { throw CalendarWriteError.noAccess }

        guard let calendar = store.calendars(for: .event).first(where: { $0.calendarIdentifier == calendarIdentifier }) else {
            throw CalendarWriteError.calendarNotFound
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar

        try store.save(event, span: .thisEvent)
        return event.eventIdentifier ?? UUID().uuidString
    }

    func fetchEvents(for date: Date, startTime: String, endTime: String) -> [CalendarEvent] {
        guard hasAccess else { return [] }

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"

        guard let startParsed = timeFmt.date(from: startTime),
              let endParsed = timeFmt.date(from: endTime) else { return [] }

        let startComps = cal.dateComponents([.hour, .minute], from: startParsed)
        let endComps = cal.dateComponents([.hour, .minute], from: endParsed)

        guard let rangeStart = cal.date(bySettingHour: startComps.hour ?? 0, minute: startComps.minute ?? 0, second: 0, of: startOfDay),
              let rangeEnd = cal.date(bySettingHour: endComps.hour ?? 23, minute: endComps.minute ?? 59, second: 0, of: startOfDay) else {
            return []
        }

        let predicate = store.predicateForEvents(withStart: rangeStart, end: rangeEnd, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        return ekEvents
            .map { CalendarEvent(from: $0) }
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
    }
}

enum CalendarWriteError: LocalizedError {
    case noAccess
    case calendarNotFound

    var errorDescription: String? {
        switch self {
        case .noAccess: return "Calendar access not granted"
        case .calendarNotFound: return "Selected calendar not found"
        }
    }
}
