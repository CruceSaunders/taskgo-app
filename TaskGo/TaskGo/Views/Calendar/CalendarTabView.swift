import SwiftUI

struct CalendarTabView: View {
    @EnvironmentObject var calendarVM: CalendarViewModel
    @EnvironmentObject var reminderVM: ReminderViewModel

    @State private var showAddReminder = false
    @State private var newTitle = ""
    @State private var newDate = Date()
    @State private var newRepeat = "none"
    @State private var newSound = true
    @State private var newNote = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Calendar access
                if !calendarVM.hasAccess {
                    calendarAccessPrompt
                    Divider()
                }

                // Today's events
                eventsSection

                Divider()

                // Reminders
                remindersSection
            }
        }
        .onAppear {
            calendarVM.checkAccess()
            reminderVM.startListening()
        }
    }

    // MARK: - Calendar Access Prompt

    private var calendarAccessPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 24))
                .foregroundStyle(Color.calmTeal)

            Text("Connect Your Calendar")
                .font(.system(size: 13, weight: .semibold))

            Text("See your Google Calendar, iCloud, and other events right here.")
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(0.5))
                .multilineTextAlignment(.center)

            Button("Allow Calendar Access") {
                Task { await calendarVM.requestAccess() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.calmTeal)
            .controlSize(.small)
        }
        .padding(16)
    }

    // MARK: - Events Section

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("TODAY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.4))

                Text(todayFormatted)
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.3))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.05))

            if calendarVM.hasAccess {
                if calendarVM.todayEvents.isEmpty {
                    HStack {
                        Spacer()
                        Text("No events today")
                            .font(.system(size: 11))
                            .foregroundStyle(.primary.opacity(0.4))
                        Spacer()
                    }
                    .padding(.vertical, 12)
                } else {
                    ForEach(calendarVM.todayEvents) { event in
                        HStack(spacing: 8) {
                            // Color dot
                            Circle()
                                .fill(event.calendarColor)
                                .frame(width: 6, height: 6)

                            // Time
                            Text(event.timeFormatted)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.5))
                                .frame(width: 55, alignment: .leading)

                            // Title
                            Text(event.title)
                                .font(.system(size: 12))
                                .lineLimit(1)

                            Spacer()

                            // Calendar name
                            Text(event.calendarName)
                                .font(.system(size: 8))
                                .foregroundStyle(.primary.opacity(0.3))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                    }
                }
            }
        }
    }

    // MARK: - Reminders Section

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("REMINDERS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.4))

                Spacer()

                Button(action: { showAddReminder.toggle() }) {
                    HStack(spacing: 3) {
                        Image(systemName: showAddReminder ? "xmark" : "plus")
                            .font(.system(size: 9))
                        Text(showAddReminder ? "Cancel" : "Add")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(Color.calmTeal)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.05))

            // Add reminder form
            if showAddReminder {
                addReminderForm
                Divider()
            }

            // Reminder list
            if reminderVM.upcomingReminders.isEmpty && !showAddReminder {
                HStack {
                    Spacer()
                    Text("No reminders")
                        .font(.system(size: 11))
                        .foregroundStyle(.primary.opacity(0.4))
                    Spacer()
                }
                .padding(.vertical, 12)
            } else {
                ForEach(reminderVM.upcomingReminders) { reminder in
                    reminderRow(reminder)
                    Divider().padding(.leading, 30)
                }
            }

            // Completed reminders
            if !reminderVM.completedReminders.isEmpty {
                HStack {
                    Text("Done")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.3))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                ForEach(reminderVM.completedReminders.prefix(5)) { reminder in
                    reminderRow(reminder)
                }
            }
        }
    }

    // MARK: - Reminder Row

    private func reminderRow(_ reminder: Reminder) -> some View {
        HStack(spacing: 8) {
            Button(action: {
                Task { await reminderVM.toggleComplete(reminder) }
            }) {
                Image(systemName: reminder.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(reminder.isComplete ? Color.calmTeal : .primary.opacity(0.3))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(reminder.title)
                    .font(.system(size: 12))
                    .strikethrough(reminder.isComplete)
                    .foregroundStyle(reminder.isComplete ? .secondary : .primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(reminder.timeFormatted)
                        .font(.system(size: 9))
                        .foregroundStyle(.primary.opacity(0.4))

                    if !reminder.repeatLabel.isEmpty {
                        Text(reminder.repeatLabel)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(3)
                    }

                    if reminder.soundEnabled {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                }
            }

            Spacer()

            if !reminder.isComplete {
                Text(reminder.dateFormatted)
                    .font(.system(size: 9))
                    .foregroundStyle(.primary.opacity(0.35))
            }

            Button(action: {
                Task { await reminderVM.deleteReminder(reminder) }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(.red.opacity(0.35))
            }
            .buttonStyle(.plain)
            .frame(width: 20)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    // MARK: - Add Reminder Form

    private var addReminderForm: some View {
        VStack(spacing: 8) {
            TextField("Reminder title", text: $newTitle)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            HStack(spacing: 8) {
                // Date & time
                DatePicker("", selection: $newDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 8) {
                // Repeat
                Text("Repeat:")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.5))

                Picker("", selection: $newRepeat) {
                    Text("None").tag("none")
                    Text("Daily").tag("daily")
                    Text("Weekly").tag("weekly")
                    Text("Monthly").tag("monthly")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
            }

            HStack {
                // Sound toggle
                Toggle(isOn: $newSound) {
                    HStack(spacing: 3) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9))
                        Text("Sound")
                            .font(.system(size: 10))
                    }
                }
                .toggleStyle(.checkbox)

                Spacer()

                Button("Add Reminder") {
                    guard !newTitle.isEmpty else { return }
                    Task {
                        await reminderVM.addReminder(
                            title: newTitle,
                            note: newNote.isEmpty ? nil : newNote,
                            scheduledDate: newDate,
                            repeatRule: newRepeat,
                            soundEnabled: newSound
                        )
                        newTitle = ""
                        newNote = ""
                        newDate = Date()
                        newRepeat = "none"
                        newSound = true
                        showAddReminder = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.calmTeal)
                .controlSize(.small)
                .disabled(newTitle.isEmpty)
            }
        }
        .padding(12)
        .background(Color.calmTeal.opacity(0.03))
    }

    // MARK: - Helpers

    private var todayFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
}
