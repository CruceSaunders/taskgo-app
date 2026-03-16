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
            groupMaxCols[groupId[i]] = max(groupMaxCols[groupId[i]] ?? 0, colAssignment[i] + 1)
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

// MARK: - Calendar Sheet

enum CalendarSheet: Identifiable {
    case createEvent
    case eventDetail(CalendarEvent)

    var id: String {
        switch self {
        case .createEvent: return "create"
        case .eventDetail(let e): return "detail-\(e.id)"
        }
    }
}

// MARK: - Calendar Tab View

struct CalendarTabView: View {
    @EnvironmentObject var calendarVM: CalendarViewModel
    @EnvironmentObject var reminderVM: ReminderViewModel

    @State private var activeSheet: CalendarSheet?
    @State private var showReminders = false
    @State private var showAddReminder = false

    // Create event form
    @State private var newEventTitle = ""
    @State private var newEventStart = Date()
    @State private var newEventEnd = Date()
    @State private var newEventCalendarId = ""
    @State private var createError: String?

    // Reminder form
    @State private var newTitle = ""
    @State private var newDate = Date()
    @State private var newRepeat = "none"
    @State private var newSound = true
    @State private var newNote = ""

    private let hourHeight: CGFloat = 48
    private let dayGutterWidth: CGFloat = 44
    private let weekGutterWidth: CGFloat = 32
    private let gridStartHour = 0
    private let gridEndHour = 24
    private let topPad: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            if !calendarVM.hasAccess {
                calendarAccessPrompt
                Divider()
            }

            navigationBar
            Divider()

            Group {
                switch calendarVM.viewMode {
                case .day:
                    dayView
                case .week:
                    weekView
                }
            }

            Divider()
            remindersToggle
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .createEvent:
                createEventSheet
                    .environmentObject(calendarVM)
            case .eventDetail(let event):
                eventDetailSheet(event)
                    .environmentObject(calendarVM)
            }
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
                let h = max(0, Calendar.current.component(.hour, from: Date()) - 2)
                proxy.scrollTo(h, anchor: .top)
            } else if let first = calendarVM.timedEvents.first {
                let h = max(0, Calendar.current.component(.hour, from: first.startDate) - 1)
                proxy.scrollTo(h, anchor: .top)
            } else {
                proxy.scrollTo(8, anchor: .top)
            }
        }
    }

    // MARK: - Access Prompt

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

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack(spacing: 6) {
            Button(action: { calendarVM.goToPrevious() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.5))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: { calendarVM.goToToday() }) {
                Text("Today")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(calendarVM.isToday ? .primary.opacity(0.35) : Color.calmTeal)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(calendarVM.isToday ? Color.primary.opacity(0.15) : Color.calmTeal.opacity(0.5), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .disabled(calendarVM.isToday)

            Button(action: { calendarVM.goToNext() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.5))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(calendarVM.navigationLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary.opacity(0.7))
                .lineLimit(1)

            Spacer()

            Picker("", selection: $calendarVM.viewMode) {
                ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 90)

            Button(action: { openCreateEvent(date: calendarVM.selectedDate, hour: Calendar.current.component(.hour, from: Date()) + 1) }) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.calmTeal)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: { calendarVM.forceRefresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.calmTeal)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.04))
    }

    // MARK: - Day View

    private var dayView: some View {
        VStack(spacing: 0) {
            if !calendarVM.allDayEvents.isEmpty {
                dayAllDaySection
                Divider()
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    dayTimeGrid
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
        }
    }

    private var dayAllDaySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(calendarVM.allDayEvents) { event in
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 1).fill(event.calendarColor).frame(width: 3)
                        Text(event.title)
                            .font(.system(size: 10)).lineLimit(1)
                            .padding(.leading, 5).padding(.trailing, 6)
                    }
                    .padding(.vertical, 4)
                    .background(event.calendarColor.opacity(0.12))
                    .cornerRadius(4)
                    .onTapGesture { activeSheet = .eventDetail(event) }
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 4)
    }

    private var dayTimeGrid: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topPad)
            ForEach(gridStartHour..<gridEndHour, id: \.self) { hour in
                dayHourRow(hour: hour)
                    .id(hour)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        openCreateEvent(date: calendarVM.selectedDate, hour: hour)
                    }
            }
            Color.clear.frame(height: topPad)
        }
        .overlay(alignment: .topLeading) {
            GeometryReader { geo in
                let eWidth = geo.size.width - dayGutterWidth - 8
                let layouts = EventLayoutEngine.computeLayouts(for: calendarVM.timedEvents)

                ZStack(alignment: .topLeading) {
                    ForEach(Array(layouts.enumerated()), id: \.1.event.id) { _, layout in
                        dayEventBlock(layout: layout, eventAreaWidth: eWidth)
                    }
                    if calendarVM.isToday {
                        dayCurrentTimeIndicator(totalWidth: geo.size.width)
                    }
                }
            }
        }
    }

    private func dayHourRow(hour: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(hourLabel(hour))
                .font(.system(size: 9))
                .foregroundStyle(.primary.opacity(0.35))
                .frame(width: dayGutterWidth - 6, alignment: .trailing)
                .offset(y: -5)

            VStack(spacing: 0) {
                Rectangle().fill(Color.primary.opacity(0.10)).frame(height: 0.5)
                Spacer()
                Rectangle().fill(Color.primary.opacity(0.05)).frame(height: 0.5)
                Spacer()
            }
            .padding(.leading, 6)
        }
        .frame(height: hourHeight)
    }

    private func dayEventBlock(layout: EventLayoutInfo, eventAreaWidth: CGFloat) -> some View {
        let event = layout.event
        let yTop = yPosition(for: event.startDate)
        let yBot = yPosition(for: event.endDate)
        let bh = max(20, yBot - yTop)
        let colW = eventAreaWidth / CGFloat(layout.totalColumns)
        let xOff = dayGutterWidth + CGFloat(layout.column) * colW + 1
        let bw = max(0, colW - 2)

        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1).fill(event.calendarColor).frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title).font(.system(size: 10, weight: .medium)).lineLimit(bh > 36 ? 2 : 1)
                if bh > 28 {
                    Text(event.timeRangeFormatted).font(.system(size: 8)).foregroundStyle(.primary.opacity(0.6)).lineLimit(1)
                }
            }
            .padding(.leading, 4).padding(.trailing, 2).padding(.vertical, 2)
            Spacer(minLength: 0)
        }
        .frame(width: bw, height: bh, alignment: .topLeading)
        .background(event.calendarColor.opacity(0.15))
        .cornerRadius(4).clipped()
        .offset(x: xOff, y: yTop + topPad)
        .onTapGesture { activeSheet = .eventDetail(event) }
    }

    private func dayCurrentTimeIndicator(totalWidth: CGFloat) -> some View {
        let y = yPosition(for: calendarVM.currentTime)
        return HStack(spacing: 0) {
            Circle().fill(Color.red).frame(width: 8, height: 8).offset(x: dayGutterWidth - 4)
            Rectangle().fill(Color.red).frame(height: 1.5)
        }
        .offset(y: y + topPad - 4)
    }

    // MARK: - Week View

    private var weekView: some View {
        VStack(spacing: 0) {
            weekHeader
            Divider()

            let hasAllDay = calendarVM.weekDates.contains { date in
                let k = Calendar.current.startOfDay(for: date)
                return !(calendarVM.weekAllDayEvents[k]?.isEmpty ?? true)
            }
            if hasAllDay {
                weekAllDaySection
                Divider()
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    weekTimeGrid
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
        }
    }

    private var weekHeader: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: weekGutterWidth)

            ForEach(Array(calendarVM.weekDates.enumerated()), id: \.1) { _, date in
                let isToday = Calendar.current.isDateInToday(date)
                VStack(spacing: 2) {
                    Text(dayAbbrev(date))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isToday ? Color.calmTeal : .primary.opacity(0.5))

                    if isToday {
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.calmTeal))
                    } else {
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .frame(width: 26, height: 26)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    calendarVM.selectDate(date)
                    calendarVM.viewMode = .day
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var weekAllDaySection: some View {
        HStack(alignment: .top, spacing: 0) {
            Color.clear.frame(width: weekGutterWidth)

            ForEach(Array(calendarVM.weekDates.enumerated()), id: \.1) { _, date in
                let key = Calendar.current.startOfDay(for: date)
                let events = calendarVM.weekAllDayEvents[key] ?? []

                VStack(spacing: 1) {
                    ForEach(events) { event in
                        Text(event.title)
                            .font(.system(size: 7, weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 2).padding(.vertical, 1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(event.calendarColor.opacity(0.85))
                            .foregroundStyle(.white)
                            .cornerRadius(2)
                            .onTapGesture { activeSheet = .eventDetail(event) }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 1)
            }
        }
        .padding(.vertical, 2)
    }

    private var weekTimeGrid: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topPad)
            ForEach(gridStartHour..<gridEndHour, id: \.self) { hour in
                weekHourRow(hour: hour).id(hour)
            }
            Color.clear.frame(height: topPad)
        }
        .overlay(alignment: .topLeading) {
            GeometryReader { geo in
                let gridW = geo.size.width - weekGutterWidth
                let dayW = gridW / 7

                ZStack(alignment: .topLeading) {
                    // Column separator lines
                    ForEach(1..<7, id: \.self) { i in
                        Rectangle()
                            .fill(Color.primary.opacity(0.06))
                            .frame(width: 0.5, height: geo.size.height)
                            .offset(x: weekGutterWidth + dayW * CGFloat(i))
                    }

                    // Events per day
                    ForEach(Array(calendarVM.weekDates.enumerated()), id: \.1) { dayIdx, date in
                        let key = Calendar.current.startOfDay(for: date)
                        let events = calendarVM.weekTimedEvents[key] ?? []
                        let layouts = EventLayoutEngine.computeLayouts(for: events)

                        ForEach(Array(layouts.enumerated()), id: \.1.event.id) { _, layout in
                            weekEventBlock(layout: layout, dayIndex: dayIdx, dayWidth: dayW)
                        }
                    }

                    // Current time indicator
                    if let todayIdx = calendarVM.weekDates.firstIndex(where: { Calendar.current.isDateInToday($0) }) {
                        weekCurrentTimeIndicator(dayIndex: todayIdx, dayWidth: dayW)
                    }
                }
            }
        }
    }

    private func weekHourRow(hour: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(shortHourLabel(hour))
                .font(.system(size: 8))
                .foregroundStyle(.primary.opacity(0.3))
                .frame(width: weekGutterWidth - 4, alignment: .trailing)
                .offset(y: -4)

            VStack(spacing: 0) {
                Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)
                Spacer()
                Rectangle().fill(Color.primary.opacity(0.04)).frame(height: 0.5)
                Spacer()
            }
            .padding(.leading, 4)
        }
        .frame(height: hourHeight)
        .contentShape(Rectangle())
    }

    private func weekEventBlock(layout: EventLayoutInfo, dayIndex: Int, dayWidth: CGFloat) -> some View {
        let event = layout.event
        let yTop = yPosition(for: event.startDate)
        let yBot = yPosition(for: event.endDate)
        let bh = max(14, yBot - yTop)
        let colW = dayWidth / CGFloat(layout.totalColumns)
        let xOff = weekGutterWidth + CGFloat(dayIndex) * dayWidth + CGFloat(layout.column) * colW + 1
        let bw = max(0, colW - 2)

        return VStack(alignment: .leading, spacing: 0) {
            Text(event.title)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(bh > 20 ? 2 : 1)
            if bh > 22 {
                Text(shortTime(event.startDate))
                    .font(.system(size: 7))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 2).padding(.vertical, 1)
        .frame(width: bw, height: bh, alignment: .topLeading)
        .background(event.calendarColor.opacity(0.85))
        .cornerRadius(2).clipped()
        .offset(x: xOff, y: yTop + topPad)
        .onTapGesture { activeSheet = .eventDetail(event) }
    }

    private func weekCurrentTimeIndicator(dayIndex: Int, dayWidth: CGFloat) -> some View {
        let y = yPosition(for: calendarVM.currentTime)
        let x = weekGutterWidth + CGFloat(dayIndex) * dayWidth

        return HStack(spacing: 0) {
            Circle().fill(Color.red).frame(width: 6, height: 6)
            Rectangle().fill(Color.red).frame(width: dayWidth - 3, height: 1.5)
        }
        .offset(x: x - 3, y: y + topPad - 3)
    }

    // MARK: - Create Event Sheet

    private var createEventSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Event")
                .font(.system(size: 15, weight: .semibold))

            TextField("Event title", text: $newEventTitle)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            DatePicker("Start", selection: $newEventStart)
                .datePickerStyle(.compact)
                .font(.system(size: 12))

            DatePicker("End", selection: $newEventEnd)
                .datePickerStyle(.compact)
                .font(.system(size: 12))

            if calendarVM.writableCalendars.isEmpty {
                Text("No writable calendars available")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Picker("Calendar", selection: $newEventCalendarId) {
                    ForEach(calendarVM.writableCalendars) { cal in
                        HStack(spacing: 4) {
                            Circle().fill(cal.color).frame(width: 8, height: 8)
                            Text(cal.title)
                        }
                        .tag(cal.id)
                    }
                }
                .font(.system(size: 12))
            }

            if let err = createError {
                Text(err)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { activeSheet = nil }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    do {
                        try calendarVM.createEvent(
                            title: newEventTitle,
                            startDate: newEventStart,
                            endDate: newEventEnd,
                            calendarId: newEventCalendarId
                        )
                        activeSheet = nil
                    } catch {
                        createError = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.calmTeal)
                .disabled(newEventTitle.isEmpty || newEventCalendarId.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
    }

    private func openCreateEvent(date: Date, hour: Int) {
        let cal = Calendar.current
        newEventTitle = ""
        createError = nil
        let clampedHour = min(hour, 23)
        newEventStart = cal.date(bySettingHour: clampedHour, minute: 0, second: 0, of: date) ?? date
        newEventEnd = cal.date(byAdding: .hour, value: 1, to: newEventStart) ?? date
        if let first = calendarVM.writableCalendars.first, newEventCalendarId.isEmpty {
            newEventCalendarId = first.id
        }
        activeSheet = .createEvent
    }

    // MARK: - Event Detail Sheet

    private func eventDetailSheet(_ event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(event.calendarColor)
                    .frame(width: 4, height: 24)
                Text(event.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
            }

            Label {
                Text(formattedEventDate(event.startDate))
                    .font(.system(size: 12))
            } icon: {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Label {
                Text(event.isAllDay ? "All day" : event.timeRangeFormatted)
                    .font(.system(size: 12))
            } icon: {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Label {
                Text(event.calendarName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "tray.full")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button(role: .destructive) {
                    do {
                        try calendarVM.deleteEvent(event)
                        activeSheet = nil
                    } catch {
                        // Silently fail if event can't be deleted
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 12))
                }

                Spacer()

                Button("Done") { activeSheet = nil }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 300)
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
                                Image(systemName: showAddReminder ? "xmark" : "plus").font(.system(size: 9))
                                Text(showAddReminder ? "Cancel" : "Add").font(.system(size: 10))
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
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.secondary.opacity(0.05))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showReminders { remindersContent }
        }
    }

    private var remindersContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if showAddReminder { addReminderForm; Divider() }

                if reminderVM.upcomingReminders.isEmpty && !showAddReminder {
                    HStack { Spacer(); Text("No reminders").font(.system(size: 11)).foregroundStyle(.primary.opacity(0.4)); Spacer() }
                        .padding(.vertical, 12)
                } else {
                    ForEach(reminderVM.upcomingReminders) { reminder in
                        reminderRow(reminder)
                        Divider().padding(.leading, 30)
                    }
                }

                if !reminderVM.completedReminders.isEmpty {
                    HStack { Text("Done").font(.system(size: 9, weight: .medium)).foregroundStyle(.primary.opacity(0.3)); Spacer() }
                        .padding(.horizontal, 12).padding(.vertical, 4)
                    ForEach(reminderVM.completedReminders.prefix(5)) { reminder in
                        reminderRow(reminder)
                    }
                }
            }
        }
        .frame(maxHeight: 180)
    }

    private func reminderRow(_ reminder: Reminder) -> some View {
        HStack(spacing: 8) {
            Button(action: { Task { await reminderVM.toggleComplete(reminder) } }) {
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
                    Text(reminder.timeFormatted).font(.system(size: 9)).foregroundStyle(.primary.opacity(0.4))
                    if !reminder.repeatLabel.isEmpty {
                        Text(reminder.repeatLabel)
                            .font(.system(size: 8, weight: .medium)).foregroundStyle(.orange)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.orange.opacity(0.1)).cornerRadius(3)
                    }
                    if reminder.soundEnabled {
                        Image(systemName: "bell.fill").font(.system(size: 7)).foregroundStyle(.primary.opacity(0.3))
                    }
                }
            }

            Spacer()

            if !reminder.isComplete {
                Text(reminder.dateFormatted).font(.system(size: 9)).foregroundStyle(.primary.opacity(0.35))
            }

            Button(action: { Task { await reminderVM.deleteReminder(reminder) } }) {
                Image(systemName: "trash").font(.system(size: 10)).foregroundStyle(.red.opacity(0.35))
            }
            .buttonStyle(.plain).frame(width: 20)
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
    }

    private var addReminderForm: some View {
        VStack(spacing: 8) {
            TextField("Reminder title", text: $newTitle)
                .textFieldStyle(.roundedBorder).font(.system(size: 12))

            HStack(spacing: 8) {
                DatePicker("", selection: $newDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden().datePickerStyle(.compact).frame(maxWidth: .infinity)
            }

            HStack(spacing: 8) {
                Text("Repeat:").font(.system(size: 10)).foregroundStyle(.primary.opacity(0.5))
                Picker("", selection: $newRepeat) {
                    Text("None").tag("none"); Text("Daily").tag("daily")
                    Text("Weekly").tag("weekly"); Text("Monthly").tag("monthly")
                }
                .pickerStyle(.segmented).frame(maxWidth: .infinity)
            }

            HStack {
                Toggle(isOn: $newSound) {
                    HStack(spacing: 3) {
                        Image(systemName: "bell.fill").font(.system(size: 9))
                        Text("Sound").font(.system(size: 10))
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
                        newTitle = ""; newNote = ""; newDate = Date()
                        newRepeat = "none"; newSound = true; showAddReminder = false
                    }
                }
                .buttonStyle(.borderedProminent).tint(Color.calmTeal).controlSize(.small)
                .disabled(newTitle.isEmpty)
            }
        }
        .padding(12)
        .background(Color.calmTeal.opacity(0.03))
    }

    // MARK: - Helpers

    private func yPosition(for date: Date) -> CGFloat {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
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

    private func shortHourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    private func dayAbbrev(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt.string(from: date).uppercased()
    }

    private func shortTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        return fmt.string(from: date).lowercased()
    }

    private func formattedEventDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d, yyyy"
        return fmt.string(from: date)
    }
}
