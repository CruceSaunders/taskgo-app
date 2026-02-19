import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class ReminderViewModel: ObservableObject {
    @Published var reminders: [Reminder] = []

    private let firestoreService = FirestoreService.shared
    private let scheduler = NotificationScheduler.shared
    private var listener: ListenerRegistration?

    var upcomingReminders: [Reminder] {
        reminders.filter { !$0.isComplete }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    var completedReminders: [Reminder] {
        reminders.filter { $0.isComplete }
            .sorted { $0.scheduledDate > $1.scheduledDate }
    }

    var todayReminders: [Reminder] {
        upcomingReminders.filter { $0.isToday }
    }

    func startListening() {
        stopListening()
        guard let userId = Auth.auth().currentUser?.uid else { return }

        listener = firestoreService.listenToReminders(userId: userId) { [weak self] reminders in
            Task { @MainActor in
                self?.reminders = reminders
                self?.scheduleAllNotifications()
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func addReminder(title: String, note: String?, scheduledDate: Date, repeatRule: String, soundEnabled: Bool) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let reminder = Reminder(
            title: title,
            note: note,
            scheduledDate: scheduledDate,
            repeatRule: repeatRule,
            soundEnabled: soundEnabled
        )

        do {
            try await firestoreService.saveReminder(reminder, userId: userId)
        } catch {
            print("[Reminders] Add error: \(error)")
        }
    }

    func toggleComplete(_ reminder: Reminder) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        var updated = reminder
        updated.isComplete.toggle()

        do {
            try await firestoreService.saveReminder(updated, userId: userId)
            if updated.isComplete, let id = reminder.id {
                scheduler.cancelNotification(id: id)
            }
        } catch {
            print("[Reminders] Toggle error: \(error)")
        }
    }

    func deleteReminder(_ reminder: Reminder) async {
        guard let userId = Auth.auth().currentUser?.uid,
              let id = reminder.id else { return }

        do {
            try await firestoreService.deleteReminder(id, userId: userId)
            scheduler.cancelNotification(id: id)
        } catch {
            print("[Reminders] Delete error: \(error)")
        }
    }

    func updateReminder(_ reminder: Reminder) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            try await firestoreService.saveReminder(reminder, userId: userId)
        } catch {
            print("[Reminders] Update error: \(error)")
        }
    }

    private func scheduleAllNotifications() {
        for reminder in upcomingReminders {
            scheduler.scheduleReminder(reminder)
        }
    }
}
