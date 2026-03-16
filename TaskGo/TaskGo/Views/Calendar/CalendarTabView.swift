import SwiftUI

// MARK: - Event Layout Engine

struct EventLayoutInfo {
    let event: CalendarEvent
    let column: Int
    let totalColumns: Int
}

enum EventLayoutEngine {
    static func computeLayouts(for events: [CalendarEvent]) -> [EventLayoutInfo] {
        guard !events.isEmpty else { return [] }

        let sorted = events.sorted { $0.startDate < $1.startDate }

        var columns: [[Int]] = []
        var colAssignment: [Int] = []

        for (i, event) in sorted.enumerated() {
            var placed = false
            for c in 0..<columns.count {
                let lastIdx = columns[c].last!
                if sorted[lastIdx].endDate <= event.startDate {
                    columns[c].append(i)
                    colAssignment.append(c)
                    placed = true
                    break
                }
            }
            if !placed {
                columns.append([i])
                colAssignment.append(columns.count - 1)
            }
        }

        var groupId = Array(repeating: 0, count: sorted.count)
        var currentGroup = 0
        var groupEnd = sorted[0].endDate

        for i in 0..<sorted.count {
            if sorted[i].startDate >= groupEnd {
                currentGroup += 1
                groupEnd = sorted[i].endDate
            } else if sorted[i].endDate > groupEnd {
                groupEnd = sorted[i].endDate
            }
            groupId[i] = currentGroup
        }

        var groupMaxCols: [Int: Int] = [:]
        for i in 0..<sorted.count {
            let gid = groupId[i]
            groupMaxCols[gid] = max(groupMaxCols[gid] ?? 0, colAssignment[i] + 1)
        }

        return sorted.enumerated().map { i, event in
            EventLayoutInfo(
                event: event,
                column: colAssignment[i],
                totalColumns: groupMaxCols[groupId[i]]!
            )
        }
    }
}

// MARK: - Calendar Tab View

struct CalendarTabView: View {
    @EnvironmentObject var calendarVM: CalendarViewModel
    @EnvironmentObject var reminderVM: ReminderViewModel

    @State private var showAddReminder = false
    @State private var showReminders = false
    @State private var newTitle = ""
    @State private var newDate = Date()
    @State private var newRepeat = "none"
    @State private var newSound = true
    @State private var newNote = ""

    private let hourHeight: CGFloat = 48
    private let gutterWidth: CGFloat = 44
    private let gridStartHour = 0
    private let gridEndHour = 24
    private let topPadding: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            if !calendarVM.hasAccess {
                calendarAccessPrompt
                Divider()
            }

            dateNavigationBar

            if !calendarVM.allDayEvents.isEmpty {
                allDayEventsSection
            }

            Divider()

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    timeGridContent
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        scrollToRelevantTime(proxy: proxy)
                    }
                }
                .onChange(of: calendarVM.selectedDate) { _, _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollToRelevantTime(proxy: proxy)
                    }
                }
            }

            Divider()

            remindersToggle
        }
        .onAppear {
            calendarVM.checkAccess()
            reminderVM.startListening()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            calendarVM.forceRefresh()
        }
    }

    private func scrollToRelevantTime(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            if calendarVM.isToday {
                let targetHour = max(0, Calendar.current.component(.hour, from: Date()) - 2)
                proxy.scrollTo(targetHour, anchor: .top)
            } else if let first = calendarVM.timedEvents.first {
                let hour = max(0, Calendar.current.component(.hour, from: first.startDate) - 1)
                proxy.scrollTo(hour, anchor: .top)
            } else {
                proxy.scrollTo(8, anchor: .top)
            }
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

    // MARK: - Date Navigation Bar

    private var dateNavigationBar: some View {
        HStack(spacing: 6) {
            Button(action: { calendarVM.goToPreviousDay() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: { calendarVM.goToToday() }) {
                Text("Today")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(calendarVM.isToday ? .primary.opacity(0.35) : Color.calmTeal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(
                                calendarVM.isToday ? Color.primary.opacity(0.15) : Color.calmTeal.opacity(0.5),
                                lineWidth: 0.5
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(calendarVM.isToday)

            Button(action: { calendarVM.goToNextDay() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(calendarVM.dateLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary.opacity(0.7))

            Spacer()

            Button(action: { calendarVM.forceRefresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.calmTeal)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.04))
    }

    // MARK: - All-Day Events

    private var allDayEventsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(calendarVM.allDayEvents) { event in
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(event.calendarColor)
                            .frame(width: 3)

                        Text(event.title)
                            .font(.system(size: 10))
                            .lineLimit(1)
                            .padding(.leading, 5)
                            .padding(.trailing, 6)
                    }
                    .padding(.vertical, 4)
                    .background(event.calendarColor.opacity(0.12))
                    .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Time Grid

    private var timeGridContent: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topPadding)

            ForEach(gridStartHour..<gridEndHour, id: \.self) { hour in
                hourRow(hour: hour)
                    .id(hour)
            }

            Color.clear.frame(height: topPadding)
        }
        .overlay(alignment: .topLeading) {
            GeometryReader { geo in
                let eventAreaWidth = geo.size.width - gutterWidth - 8
                let layouts = EventLayoutEngine.computeLayouts(for: calendarVM.timedEvents)

                ZStack(alignment: .topLeading) {
                    ForEach(Array(layouts.enumerated()), id: \.1.event.id) { _, layout in
                        eventBlock(layout: layout, eventAreaWidth: eventAreaWidth)
                    }

                    if calendarVM.isToday {
                        currentTimeIndicator(totalWidth: geo.size.width)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func hourRow(hour: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(hourLabel(hour))
                .font(.system(size: 9))
                .foregroundStyle(.primary.opacity(0.35))
                .frame(width: gutterWidth - 6, alignment: .trailing)
                .offset(y: -5)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.primary.opacity(0.10))
                    .frame(height: 0.5)

                Spacer()

                Rectangle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 0.5)

                Spacer()
            }
            .padding(.leading, 6)
        }
        .frame(height: hourHeight)
    }

    // MARK: - Event Block

    private func eventBlock(layout: EventLayoutInfo, eventAreaWidth: CGFloat) -> some View {
        let event = layout.event
        let yTop = yPositionInGrid(for: event.startDate)
        let yBottom = yPositionInGrid(for: event.endDate)
        let blockHeight = max(20, yBottom - yTop)

        let columnWidth = eventAreaWidth / CGFloat(layout.totalColumns)
        let xOffset = gutterWidth + CGFloat(layout.column) * columnWidth + 1
        let blockWidth = max(0, columnWidth - 2)

        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1)
                .fill(event.calendarColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(blockHeight > 36 ? 2 : 1)

                if blockHeight > 28 {
                    Text(event.timeRangeFormatted)
                        .font(.system(size: 8))
                        .foregroundStyle(.primary.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .padding(.leading, 4)
            .padding(.trailing, 2)
            .padding(.vertical, 2)

            Spacer(minLength: 0)
        }
        .frame(width: blockWidth, height: blockHeight, alignment: .topLeading)
        .background(event.calendarColor.opacity(0.15))
        .cornerRadius(4)
        .clipped()
        .offset(x: xOffset, y: yTop + topPadding)
    }

    // MARK: - Current Time Indicator

    private func currentTimeIndicator(totalWidth: CGFloat) -> some View {
        let y = yPositionInGrid(for: calendarVM.currentTime)

        return HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .offset(x: gutterWidth - 4)

            Rectangle()
                .fill(Color.red)
                .frame(height: 1.5)
        }
        .offset(y: y + topPadding - 4)
    }

    // MARK: - Reminders

    private var remindersToggle: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { showReminders.toggle() }
            }) {
                HStack {
                    Text("REMINDERS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.4))

                    Image(systemName: showReminders ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.3))

                    Spacer()

                    if showReminders {
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
                    } else {
                        Text("\(reminderVM.upcomingReminders.count)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.05))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showReminders {
                remindersContent
            }
        }
    }

    private var remindersContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if showAddReminder {
                    addReminderForm
                    Divider()
                }

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
        .frame(maxHeight: 180)
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
                DatePicker("", selection: $newDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 8) {
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

    private func yPositionInGrid(for date: Date) -> CGFloat {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: calendarVM.selectedDate)
        let totalMinutes = date.timeIntervalSince(startOfDay) / 60
        let clamped = max(0, min(totalMinutes, Double(gridEndHour * 60)))
        return CGFloat(clamped) / 60.0 * hourHeight
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
}
