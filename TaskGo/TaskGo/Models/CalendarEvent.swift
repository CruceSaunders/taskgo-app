import SwiftUI
import EventKit

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarColor: Color
    let calendarName: String

    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier ?? UUID().uuidString
        self.title = ekEvent.title ?? "Untitled"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        if let cgColor = ekEvent.calendar.cgColor {
            self.calendarColor = Color(cgColor: cgColor)
        } else {
            self.calendarColor = .blue
        }
        self.calendarName = ekEvent.calendar.title
    }

    var timeFormatted: String {
        if isAllDay { return "All day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startDate)
    }

    var endTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: endDate)
    }
}
