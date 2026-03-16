import SwiftUI
import EventKit

struct PlannerTabView: View {
    @EnvironmentObject var plannerVM: PlannerViewModel
    @State private var showOfficeHoursSetup = false

    var body: some View {
        HStack(spacing: 0) {
            plannerSidebar
                .frame(width: 120)

            Divider()

            if plannerVM.showCreatePlan {
                CreatePlanView()
            } else {
                PlanDetailView()
            }
        }
        .onAppear {
            plannerVM.startListening()
            plannerVM.loadOfficeHoursAndCalendar()
        }
        .onDisappear {
            plannerVM.flushSave()
        }
    }

    // MARK: - Sidebar

    private var plannerSidebar: some View {
        VStack(spacing: 0) {
            // New Plan button
            Button(action: { plannerVM.showCreatePlan = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                    Text("New Plan")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color.calmTeal)
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 4)

            // Filter pills
            filterBar
                .padding(.horizontal, 6)
                .padding(.bottom, 4)

            Divider()

            // Plan list
            if plannerVM.filteredPlans.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "tray")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary.opacity(0.15))
                    Text(plannerVM.filter == .completed ? "No completed plans" : "No plans yet")
                        .font(.system(size: 9))
                        .foregroundStyle(.primary.opacity(0.3))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(plannerVM.filteredPlans) { plan in
                            planCard(plan)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            }

            Divider()
            officeHoursFooter
        }
        .background(Color.secondary.opacity(0.04))
    }

    // MARK: - Office Hours Footer

    private var officeHoursFooter: some View {
        VStack(spacing: 4) {
            if let oh = plannerVM.officeHours {
                Button(action: { showOfficeHoursSetup = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.calmTeal)
                        Text(oh.displayLabel)
                            .font(.system(size: 8))
                            .foregroundStyle(.primary.opacity(0.5))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.system(size: 7))
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { showOfficeHoursSetup = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 9))
                        Text("Set Office Hours")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(Color.calmTeal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color.calmTeal.opacity(0.08))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            if let calId = plannerVM.selectedCalendarId,
               let calName = CalendarService.shared.calendarTitle(for: calId) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 7))
                        .foregroundStyle(.primary.opacity(0.4))
                    Text(calName)
                        .font(.system(size: 8))
                        .foregroundStyle(.primary.opacity(0.4))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .popover(isPresented: $showOfficeHoursSetup, arrowEdge: .trailing) {
            OfficeHoursSetupView()
                .environmentObject(plannerVM)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 0) {
            ForEach(PlanFilter.allCases, id: \.self) { f in
                Button(action: { plannerVM.filter = f }) {
                    Text(f.rawValue)
                        .font(.system(size: 9, weight: plannerVM.filter == f ? .semibold : .regular))
                        .foregroundStyle(plannerVM.filter == f ? Color.calmTeal : .primary.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .background(plannerVM.filter == f ? Color.calmTeal.opacity(0.12) : Color.clear)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(4)
    }

    // MARK: - Plan Card

    private func planCard(_ plan: Plan) -> some View {
        Button(action: { plannerVM.selectPlan(plan) }) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if plan.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                    }
                    Text(plan.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(plannerVM.selectedPlan?.id == plan.id ? .white : .primary.opacity(0.85))
                        .lineLimit(1)
                }

                Text(plan.displayDateRange)
                    .font(.system(size: 8))
                    .foregroundStyle(plannerVM.selectedPlan?.id == plan.id ? .white.opacity(0.7) : .primary.opacity(0.4))

                if plan.totalObjectives > 0 {
                    HStack(spacing: 4) {
                        progressMini(plan)
                        Text("\(plan.completedObjectives)/\(plan.totalObjectives)")
                            .font(.system(size: 8).monospacedDigit())
                            .foregroundStyle(plannerVM.selectedPlan?.id == plan.id ? .white.opacity(0.6) : .primary.opacity(0.35))
                    }
                } else {
                    Text("\(plan.dayCount) day\(plan.dayCount == 1 ? "" : "s")")
                        .font(.system(size: 8))
                        .foregroundStyle(plannerVM.selectedPlan?.id == plan.id ? .white.opacity(0.6) : .primary.opacity(0.35))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(plannerVM.selectedPlan?.id == plan.id ? Color.calmTeal : Color.clear)
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(plan.isComplete ? "Reopen Plan" : "Complete Plan") {
                plannerVM.selectPlan(plan)
                if plan.isComplete {
                    plannerVM.reopenPlan()
                } else {
                    plannerVM.completePlan()
                }
            }
            Divider()
            Button("Delete Plan", role: .destructive) {
                plannerVM.deletePlan(plan)
            }
        }
    }

    private func progressMini(_ plan: Plan) -> some View {
        let isSelected = plannerVM.selectedPlan?.id == plan.id
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.12))
                    .frame(height: 3)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? Color.white.opacity(0.8) : Color.calmTeal)
                    .frame(width: max(0, geo.size.width * plan.progress), height: 3)
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Office Hours Setup View

struct OfficeHoursSetupView: View {
    @EnvironmentObject var plannerVM: PlannerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var startHour = 9
    @State private var startMinute = 0
    @State private var endHour = 17
    @State private var endMinute = 0
    @State private var workDays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var selectedCalId: String = ""

    private let dayLabels: [(id: Int, label: String)] = [
        (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Office Hours")
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Work Hours")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.6))

                HStack(spacing: 8) {
                    timePicker(label: "Start", hour: $startHour, minute: $startMinute)
                    Text("to")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.5))
                    timePicker(label: "End", hour: $endHour, minute: $endMinute)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Work Days")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.6))

                HStack(spacing: 3) {
                    ForEach(dayLabels, id: \.id) { day in
                        Button(action: {
                            if workDays.contains(day.id) {
                                workDays.remove(day.id)
                            } else {
                                workDays.insert(day.id)
                            }
                        }) {
                            Text(day.label)
                                .font(.system(size: 9, weight: workDays.contains(day.id) ? .semibold : .regular))
                                .foregroundStyle(workDays.contains(day.id) ? .white : .primary.opacity(0.5))
                                .frame(width: 28, height: 22)
                                .background(workDays.contains(day.id) ? Color.calmTeal : Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Calendar")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.6))

                if plannerVM.availableCalendars.isEmpty {
                    Text("No writable calendars found")
                        .font(.system(size: 9))
                        .foregroundStyle(.primary.opacity(0.4))
                } else {
                    Picker("", selection: $selectedCalId) {
                        Text("Select calendar...").tag("")
                        ForEach(plannerVM.availableCalendars, id: \.calendarIdentifier) { cal in
                            Text(cal.title).tag(cal.calendarIdentifier)
                        }
                    }
                    .labelsHidden()
                    .font(.system(size: 10))
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.5))

                Button(action: save) {
                    Text("Save")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.calmTeal)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .disabled(workDays.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 260)
        .onAppear {
            plannerVM.refreshCalendars()
            if let oh = plannerVM.officeHours {
                let startParts = oh.startTime.split(separator: ":").compactMap { Int($0) }
                let endParts = oh.endTime.split(separator: ":").compactMap { Int($0) }
                if startParts.count == 2 { startHour = startParts[0]; startMinute = startParts[1] }
                if endParts.count == 2 { endHour = endParts[0]; endMinute = endParts[1] }
                workDays = Set(oh.workDays)
            }
            if let calId = plannerVM.selectedCalendarId {
                selectedCalId = calId
            }
        }
    }

    private func timePicker(label: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 2) {
            Picker("", selection: hour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%d", h == 0 ? 12 : (h > 12 ? h - 12 : h))).tag(h)
                }
            }
            .labelsHidden()
            .frame(width: 40)

            Text(":")
                .font(.system(size: 10))

            Picker("", selection: minute) {
                ForEach([0, 15, 30, 45], id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .labelsHidden()
            .frame(width: 40)

            Text(hour.wrappedValue >= 12 ? "PM" : "AM")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.primary.opacity(0.5))
        }
    }

    private func save() {
        let oh = OfficeHours(
            startTime: String(format: "%02d:%02d", startHour, startMinute),
            endTime: String(format: "%02d:%02d", endHour, endMinute),
            workDays: Array(workDays).sorted()
        )
        plannerVM.saveOfficeHours(oh)
        if !selectedCalId.isEmpty {
            plannerVM.saveSelectedCalendar(selectedCalId)
        }
        dismiss()
    }
}
