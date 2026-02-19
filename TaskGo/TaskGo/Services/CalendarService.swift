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
}
