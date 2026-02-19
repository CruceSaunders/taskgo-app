import UserNotifications
import AppKit

class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private var alarmPlayer: NSSound?

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("[Notifications] Permission error: \(error)")
            return false
        }
    }

    // MARK: - Schedule Reminder

    func scheduleReminder(_ reminder: Reminder) {
        guard let id = reminder.id else { return }
        guard !reminder.isComplete else {
            cancelNotification(id: id)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "TaskGo! Reminder"
        content.body = reminder.title
        if let note = reminder.note, !note.isEmpty {
            content.subtitle = note
        }
        content.sound = reminder.soundEnabled ? .default : nil
        content.categoryIdentifier = "REMINDER"

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.scheduledDate
        )

        let repeats: Bool
        var triggerComponents = dateComponents

        switch reminder.repeatRule {
        case "daily":
            triggerComponents = Calendar.current.dateComponents([.hour, .minute], from: reminder.scheduledDate)
            repeats = true
        case "weekly":
            triggerComponents = Calendar.current.dateComponents([.weekday, .hour, .minute], from: reminder.scheduledDate)
            repeats = true
        case "monthly":
            triggerComponents = Calendar.current.dateComponents([.day, .hour, .minute], from: reminder.scheduledDate)
            repeats = true
        default:
            repeats = false
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: repeats)
        let request = UNNotificationRequest(identifier: "reminder-\(id)", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("[Notifications] Schedule error: \(error)")
            } else {
                print("[Notifications] Scheduled reminder: \(reminder.title) at \(reminder.scheduledDate)")
            }
        }
    }

    // MARK: - Schedule Calendar Event Alert

    func scheduleCalendarAlert(_ event: CalendarEvent, minutesBefore: Int = 5) {
        guard !event.isAllDay else { return }

        let alertDate = event.startDate.addingTimeInterval(-Double(minutesBefore * 60))
        guard alertDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming: \(event.title)"
        content.body = "Starts at \(event.timeFormatted)"
        content.sound = .default
        content.categoryIdentifier = "CALENDAR"

        let interval = alertDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: "cal-\(event.id)", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("[Notifications] Calendar alert error: \(error)")
            }
        }
    }

    // MARK: - Cancel

    func cancelNotification(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["reminder-\(id)"])
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Reschedule All

    func rescheduleAll(reminders: [Reminder], events: [CalendarEvent]) {
        cancelAll()

        for reminder in reminders where !reminder.isComplete {
            scheduleReminder(reminder)
        }

        for event in events {
            scheduleCalendarAlert(event)
        }
    }

    // MARK: - Alarm Sound

    func playAlarmSound() {
        alarmPlayer?.stop()
        alarmPlayer = NSSound(named: "Glass")
        alarmPlayer?.loops = true
        alarmPlayer?.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.alarmPlayer?.loops = false
            self?.alarmPlayer?.stop()
        }
    }
}
