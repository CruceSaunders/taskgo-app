import SwiftUI

struct PlanDetailView: View {
    @EnvironmentObject var plannerVM: PlannerViewModel
    @State private var confirmDelete = false
    @State private var showScheduleConfig = false
    @State private var scheduleStart = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var scheduleEnd = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()
    @State private var selectedCalId: String = ""
    @State private var calendarInfos: [WritableCalendarInfo] = []

    var body: some View {
        if let plan = plannerVM.selectedPlan {
            ZStack {
                VStack(spacing: 0) {
                    planHeader(plan)
                    if !plan.isComplete {
                        scheduleConfigSection(plan)
                    }
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            overallSection(plan)
                            dailySections(plan)
                        }
                        .padding(.bottom, 16)
                    }
                }

                if plannerVM.conversionState != .idle {
                    conversionOverlay
                }
            }
            .onAppear { loadScheduleState(from: plan) }
            .onChange(of: plannerVM.selectedPlan?.id) { _, _ in
                if let p = plannerVM.selectedPlan { loadScheduleState(from: p) }
            }
        } else {
            emptyState
        }
    }

    private func loadScheduleState(from plan: Plan) {
        calendarInfos = CalendarService.shared.getWritableCalendarInfos()
        let cal = Calendar.current
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        if let st = plan.scheduleStartTime, let parsed = timeFmt.date(from: st) {
            let comps = cal.dateComponents([.hour, .minute], from: parsed)
            scheduleStart = cal.date(from: comps) ?? scheduleStart
        }
        if let et = plan.scheduleEndTime, let parsed = timeFmt.date(from: et) {
            let comps = cal.dateComponents([.hour, .minute], from: parsed)
            scheduleEnd = cal.date(from: comps) ?? scheduleEnd
        }
        selectedCalId = plan.calendarId ?? ""
    }

    // MARK: - Header

    private func planHeader(_ plan: Plan) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    EditableTitle(
                        text: plan.title,
                        onCommit: { plannerVM.updatePlanTitle($0) }
                    )
                    HStack(spacing: 6) {
                        Text(plan.displayDateRange)
                            .font(.system(size: 10))
                            .foregroundStyle(.primary.opacity(0.5))
                        Text("·")
                            .foregroundStyle(.primary.opacity(0.3))
                        Text("\(plan.dayCount) day\(plan.dayCount == 1 ? "" : "s")")
                            .font(.system(size: 10))
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                }
                Spacer()
                if confirmDelete {
                    Text("Delete?")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                    Button(action: {
                        plannerVM.deletePlan(plan)
                        confirmDelete = false
                    }) {
                        Text("Yes")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    Button(action: { confirmDelete = false }) {
                        Text("No")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { confirmDelete = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.5))
                    }
                    .buttonStyle(.plain)

                    if plan.isComplete {
                        Button(action: { plannerVM.reopenPlan() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 9))
                                Text("Reopen")
                                    .font(.system(size: 9, weight: .medium))
                                    .lineLimit(1)
                            }
                            .fixedSize()
                            .foregroundStyle(Color.calmTeal)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.calmTeal.opacity(0.12))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: { plannerVM.convertToCalendar() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 9))
                                Text(plan.lastConvertedAt != nil ? "Reconvert" : "To Cal")
                                    .font(.system(size: 9, weight: .medium))
                                    .lineLimit(1)
                            }
                            .fixedSize()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)

                        Button(action: { plannerVM.completePlan() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 9))
                                Text("Done")
                                    .font(.system(size: 9, weight: .medium))
                                    .lineLimit(1)
                            }
                            .fixedSize()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.calmTeal)
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if plan.isComplete {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text("Plan Completed")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.green)
                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.green.opacity(0.08))
                .cornerRadius(4)
            }

            if plan.totalObjectives > 0 {
                progressBar(plan)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func progressBar(_ plan: Plan) -> some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.calmTeal)
                        .frame(width: geo.size.width * plan.progress, height: 4)
                        .animation(.easeInOut(duration: 0.2), value: plan.progress)
                }
            }
            .frame(height: 4)

            Text("\(plan.completedObjectives)/\(plan.totalObjectives)")
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.primary.opacity(0.4))
        }
    }

    // MARK: - Schedule Config (per-plan)

    private func scheduleConfigSection(_ plan: Plan) -> some View {
        VStack(spacing: 0) {
            if plan.hasScheduleConfig && !showScheduleConfig {
                Button(action: { showScheduleConfig = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.calmTeal)
                        if let label = plan.scheduleDisplayLabel {
                            Text(label)
                                .font(.system(size: 10))
                                .foregroundStyle(.primary.opacity(0.6))
                        }
                        if let calId = plan.calendarId,
                           let info = calendarInfos.first(where: { $0.identifier == calId }) {
                            Text("on \(info.displayLabel)")
                                .font(.system(size: 10))
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.system(size: 8))
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if !plan.hasScheduleConfig {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.calmTeal)
                            Text("Set schedule hours and calendar to convert this plan to calendar events")
                                .font(.system(size: 9))
                                .foregroundStyle(.primary.opacity(0.5))
                        }
                    }

                    HStack(spacing: 6) {
                        Text("From")
                            .font(.system(size: 10))
                            .foregroundStyle(.primary.opacity(0.5))
                        DatePicker("", selection: $scheduleStart, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .frame(width: 80)
                        Text("to")
                            .font(.system(size: 10))
                            .foregroundStyle(.primary.opacity(0.5))
                        DatePicker("", selection: $scheduleEnd, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .frame(width: 80)
                    }

                    HStack(spacing: 6) {
                        Text("Calendar")
                            .font(.system(size: 10))
                            .foregroundStyle(.primary.opacity(0.5))
                        if calendarInfos.isEmpty {
                            Text("No writable calendars found")
                                .font(.system(size: 9))
                                .foregroundStyle(.primary.opacity(0.4))
                        } else {
                            Picker("", selection: $selectedCalId) {
                                Text("Choose...").tag("")
                                ForEach(calendarInfos) { info in
                                    Text(info.displayLabel).tag(info.identifier)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 200)
                        }
                    }

                    HStack {
                        Spacer()
                        if plan.hasScheduleConfig {
                            Button("Cancel") { showScheduleConfig = false }
                                .buttonStyle(.plain)
                                .font(.system(size: 9))
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                        Button(action: saveScheduleConfig) {
                            Text("Save")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Color.calmTeal)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedCalId.isEmpty)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.04))
            }
            Divider()
        }
    }

    private func saveScheduleConfig() {
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let startStr = timeFmt.string(from: scheduleStart)
        let endStr = timeFmt.string(from: scheduleEnd)
        plannerVM.updateScheduleTimes(start: startStr, end: endStr)
        if !selectedCalId.isEmpty {
            plannerVM.updateCalendarId(selectedCalId)
        }
        showScheduleConfig = false
    }

    // MARK: - Overall Objectives

    private func overallSection(_ plan: Plan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "Plan Objectives", systemImage: "flag.fill")
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)

            ForEach(plan.overallObjectives) { obj in
                ObjectiveRow(
                    objective: obj,
                    isComplete: plan.isComplete,
                    onToggle: { plannerVM.toggleObjective(objectiveId: obj.id, date: nil) },
                    onUpdate: { plannerVM.updateObjectiveText(objectiveId: obj.id, date: nil, newText: $0) },
                    onDelete: { plannerVM.removeObjective(objectiveId: obj.id, date: nil) },
                    onDurationChange: { plannerVM.updateObjectiveDuration(objectiveId: obj.id, date: nil, minutes: $0) }
                )
            }

            if !plan.isComplete {
                AddObjectiveField { text in
                    plannerVM.addOverallObjective(text: text)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }

            Divider()
                .padding(.top, 4)
        }
    }

    // MARK: - Daily Sections

    private func dailySections(_ plan: Plan) -> some View {
        ForEach(plan.dateRange, id: \.self) { dateStr in
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader(
                    title: Plan.displayDayLabel(for: dateStr),
                    systemImage: dateStr == Plan.todayString ? "sun.max.fill" : "calendar"
                )
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)

                let objectives = plan.dailyObjectives[dateStr] ?? []
                ForEach(objectives) { obj in
                    ObjectiveRow(
                        objective: obj,
                        isComplete: plan.isComplete,
                        onToggle: { plannerVM.toggleObjective(objectiveId: obj.id, date: dateStr) },
                        onUpdate: { plannerVM.updateObjectiveText(objectiveId: obj.id, date: dateStr, newText: $0) },
                        onDelete: { plannerVM.removeObjective(objectiveId: obj.id, date: dateStr) },
                        onDurationChange: { plannerVM.updateObjectiveDuration(objectiveId: obj.id, date: dateStr, minutes: $0) }
                    )
                }

                if objectives.isEmpty && plan.isComplete {
                    Text("No objectives")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.25))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 4)
                }

                if !plan.isComplete {
                    AddObjectiveField { text in
                        plannerVM.addDailyObjective(date: dateStr, text: text)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }

                Divider()
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 9))
                .foregroundStyle(Color.calmTeal)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.8))
            Spacer()
        }
    }

    // MARK: - Conversion Overlay

    @ViewBuilder
    private var conversionOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                switch plannerVM.conversionState {
                case .idle:
                    EmptyView()

                case .validating:
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Validating...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))

                case .scheduling:
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("AI is scheduling your tasks...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))

                case .creatingEvents:
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Creating calendar events...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))

                case .success(let count):
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)
                    Text("Created \(count) event\(count == 1 ? "" : "s") on your calendar")
                        .font(.system(size: 12, weight: .medium))
                    Button("Done") { plannerVM.dismissConversionResult() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 5)
                        .background(Color.calmTeal)
                        .cornerRadius(5)

                case .error(let error):
                    conversionErrorView(error)
                }
            }
            .padding(20)
            .background(.regularMaterial)
            .cornerRadius(10)
            .shadow(radius: 8)
            .frame(maxWidth: 320)
        }
    }

    @ViewBuilder
    private func conversionErrorView(_ error: ConversionError) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)

            switch error {
            case .noScheduleConfig:
                Text("Schedule Not Configured")
                    .font(.system(size: 12, weight: .semibold))
                Text("Set your schedule hours and calendar for this plan before converting.")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.6))
                    .multilineTextAlignment(.center)

            case .noCalendarAccess:
                Text("Calendar Access Required")
                    .font(.system(size: 12, weight: .semibold))
                Text("Grant calendar access in the Calendar tab to create events.")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.6))
                    .multilineTextAlignment(.center)

            case .missingDurations(let count, _):
                Text("Missing Time Estimates")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(count) objective\(count == 1 ? " is" : "s are") missing a duration. Set a time for each task before converting.")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.6))
                    .multilineTextAlignment(.center)

            case .dayOverflow(let details):
                Text("Not Enough Time")
                    .font(.system(size: 12, weight: .semibold))
                Text("Some days have more tasks than available hours:")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.6))

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(details, id: \.date) { detail in
                        HStack {
                            Text(Plan.displayDayLabel(for: detail.date))
                                .font(.system(size: 9, weight: .medium))
                            Spacer()
                            Text("\(formatMin(detail.neededMinutes)) needed, \(formatMin(detail.availableMinutes)) available")
                                .font(.system(size: 9))
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(8)
                .background(Color.red.opacity(0.06))
                .cornerRadius(6)

            case .nothingToConvert:
                Text("Nothing to Convert")
                    .font(.system(size: 12, weight: .semibold))
                Text("There are no incomplete daily objectives to schedule.")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.6))
                    .multilineTextAlignment(.center)

            case .alreadyConverted(let date):
                Text("Already Converted")
                    .font(.system(size: 12, weight: .semibold))
                Text("This plan was converted on \(formattedDate(date)). Previous events will not be removed.")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.6))
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Button("Cancel") { plannerVM.dismissConversionResult() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.5))

                    Button("Convert Again") { plannerVM.convertToCalendar(forceReconvert: true) }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(5)
                }

            case .aiError(let msg):
                Text("Scheduling Error")
                    .font(.system(size: 12, weight: .semibold))
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.6))
                    .multilineTextAlignment(.center)

            case .calendarWriteError(let msg):
                Text("Calendar Error")
                    .font(.system(size: 12, weight: .semibold))
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            Button("Dismiss") { plannerVM.dismissConversionResult() }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.4))
                .cornerRadius(5)
        }
    }

    private func formatMin(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.day.timeline.leading")
                .font(.system(size: 28))
                .foregroundStyle(.primary.opacity(0.15))
            Text("Select a plan or create a new one")
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Objective Row

struct ObjectiveRow: View {
    let objective: PlanObjective
    let isComplete: Bool
    let onToggle: () -> Void
    let onUpdate: (String) -> Void
    let onDelete: () -> Void
    var onDurationChange: ((Int?) -> Void)? = nil

    @State private var isEditing = false
    @State private var editText = ""
    @State private var isHovering = false
    @State private var showDurationPicker = false
    @State private var durationValue: Int = 30

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onToggle) {
                Image(systemName: objective.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(objective.isComplete ? Color.calmTeal : .primary.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(isComplete)

            if isEditing {
                TextField("", text: $editText, onCommit: commitEdit)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .onExitCommand { isEditing = false }
            } else {
                Text(objective.text)
                    .font(.system(size: 11))
                    .strikethrough(objective.isComplete, color: .primary.opacity(0.3))
                    .foregroundStyle(Color.primary.opacity(objective.isComplete ? 0.4 : 0.8))
                    .onTapGesture(count: 2) {
                        guard !isComplete else { return }
                        editText = objective.text
                        isEditing = true
                    }
            }

            Spacer()

            if onDurationChange != nil && !isComplete {
                durationBadge
            }

            if isHovering && !isComplete {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var durationBadge: some View {
        if let minutes = objective.estimatedMinutes, minutes > 0 {
            Button(action: {
                durationValue = minutes
                showDurationPicker = true
            }) {
                Text(formatDuration(minutes))
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.calmTeal)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.calmTeal.opacity(0.1))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDurationPicker, arrowEdge: .bottom) {
                durationPickerContent
            }
        } else if !objective.isComplete {
            Button(action: {
                durationValue = 30
                showDurationPicker = true
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text("set time")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.primary.opacity(0.3))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDurationPicker, arrowEdge: .bottom) {
                durationPickerContent
            }
        }
    }

    private var durationPickerContent: some View {
        VStack(spacing: 8) {
            Text("Duration")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.7))

            HStack(spacing: 8) {
                Button(action: { if durationValue > 5 { durationValue -= 5 } }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .buttonStyle(.plain)

                Text(formatDuration(durationValue))
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .frame(minWidth: 50)

                Button(action: { if durationValue < 480 { durationValue += 5 } }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 4) {
                ForEach([15, 30, 60, 120], id: \.self) { preset in
                    Button(action: { durationValue = preset }) {
                        Text(formatDuration(preset))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(durationValue == preset ? .white : .primary.opacity(0.6))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(durationValue == preset ? Color.calmTeal : Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: {
                onDurationChange?(durationValue)
                showDurationPicker = false
            }) {
                Text("Set")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(Color.calmTeal)
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 180)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }

    private func commitEdit() {
        isEditing = false
        if !editText.trimmingCharacters(in: .whitespaces).isEmpty {
            onUpdate(editText)
        }
    }
}

// MARK: - Add Objective Field

struct AddObjectiveField: View {
    let onAdd: (String) -> Void
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 9))
                .foregroundStyle(.primary.opacity(0.25))
            TextField("Add objective...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(0.6))
                .focused($isFocused)
                .onSubmit {
                    guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    onAdd(text)
                    text = ""
                    isFocused = true
                }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Editable Title

struct EditableTitle: View {
    let text: String
    let onCommit: (String) -> Void

    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        if isEditing {
            TextField("", text: $editText, onCommit: {
                isEditing = false
                if !editText.trimmingCharacters(in: .whitespaces).isEmpty {
                    onCommit(editText)
                }
            })
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .onExitCommand { isEditing = false }
        } else {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .onTapGesture(count: 2) {
                    editText = text
                    isEditing = true
                }
        }
    }
}
