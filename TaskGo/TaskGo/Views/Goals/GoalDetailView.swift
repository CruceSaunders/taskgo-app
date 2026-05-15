import SwiftUI

struct GoalDetailView: View {
    @EnvironmentObject var goalVM: GoalViewModel
    let goal: Goal

    @State private var editedTitle: String = ""
    @State private var titleFocused: Bool = false
    @State private var newMilestoneTitle: String = ""
    @State private var editingNotes: String = ""
    @State private var editingTimeline: Bool = false
    @State private var timelineStart: Date = Date()
    @State private var timelineHasEnd: Bool = false
    @State private var timelineEnd: Date = Date()
    @State private var showingDeleteConfirm: Bool = false
    @State private var editingElapsed: Bool = false
    @State private var elapsedHours: String = ""
    @State private var elapsedMinutes: String = ""
    @State private var elapsedSeconds: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleAndActions
                stopwatchSection
                timelineSection
                milestonesSection
                notesSection
                if goal.isCompleted { statsSection }
                dangerZone
            }
            .padding(16)
        }
        .onAppear {
            editedTitle = goal.title
            editingNotes = goal.notes
            timelineStart = goal.startDate
            timelineEnd = goal.estimatedEndDate ?? Calendar.current.date(byAdding: .day, value: 14, to: goal.startDate) ?? Date()
            timelineHasEnd = goal.estimatedEndDate != nil
        }
        .onChange(of: goal.id) { _, _ in
            editedTitle = goal.title
            editingNotes = goal.notes
            timelineStart = goal.startDate
            timelineEnd = goal.estimatedEndDate ?? Calendar.current.date(byAdding: .day, value: 14, to: goal.startDate) ?? Date()
            timelineHasEnd = goal.estimatedEndDate != nil
        }
        .confirmationDialog(
            "Delete \"\(goal.title)\"?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                goalVM.deleteGoal(goal)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently deletes the goal and all its milestones.")
        }
    }

    // MARK: - Title

    private var titleAndActions: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Goal title", text: $editedTitle, onCommit: commitTitle)
                    .font(.system(size: 20, weight: .bold))
                    .textFieldStyle(.plain)
                    .onSubmit(commitTitle)

                HStack(spacing: 8) {
                    if goal.isCompleted {
                        Label("Completed", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.green)
                    } else {
                        Text("Active")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.calmTeal)
                    }

                    if !goal.milestones.isEmpty {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("\(goal.completedMilestoneCount) of \(goal.milestones.count) milestones")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if goal.isCompleted {
                Button(action: { goalVM.reopenGoal(goal) }) {
                    Label("Reopen", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button(action: { goalVM.markGoalComplete(goal) }) {
                    Label("Complete", systemImage: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.calmTeal)
                .controlSize(.small)
            }
        }
    }

    private func commitTitle() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != goal.title {
            goalVM.renameGoal(goal, to: trimmed)
        } else {
            editedTitle = goal.title
        }
    }

    // MARK: - Stopwatch

    private var stopwatchSection: some View {
        let _ = goalVM.stopwatchTick
        let live = goalVM.liveElapsedSeconds(goal)
        return SectionCard(title: "Time Spent", icon: "stopwatch") {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Goal.formatElapsed(live))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(goal.isStopwatchRunning ? Color.calmTeal : .primary)
                    HStack(spacing: 6) {
                        if goal.isStopwatchRunning {
                            Circle().fill(Color.red).frame(width: 6, height: 6)
                            Text("Running")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.red)
                        } else {
                            Text("Stopped")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                if !goal.isCompleted {
                    Button(action: { goalVM.toggleStopwatch(goal) }) {
                        HStack(spacing: 6) {
                            Image(systemName: goal.isStopwatchRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 12))
                            Text(goal.isStopwatchRunning ? "Pause" : "Start")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(goal.isStopwatchRunning ? Color.red.opacity(0.85) : Color.calmTeal)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button(action: openElapsedEditor) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Edit total time")
            }
        }
        .sheet(isPresented: $editingElapsed) {
            EditElapsedSheet(
                isPresented: $editingElapsed,
                hours: $elapsedHours,
                minutes: $elapsedMinutes,
                seconds: $elapsedSeconds,
                onSave: commitElapsedEdit
            )
        }
    }

    private func openElapsedEditor() {
        let live = goalVM.liveElapsedSeconds(goal)
        elapsedHours = String(live / 3600)
        elapsedMinutes = String((live % 3600) / 60)
        elapsedSeconds = String(live % 60)
        editingElapsed = true
    }

    private func commitElapsedEdit() {
        let h = max(0, Int(elapsedHours) ?? 0)
        let m = max(0, Int(elapsedMinutes) ?? 0)
        let s = max(0, Int(elapsedSeconds) ?? 0)
        goalVM.setManualElapsed(goal, seconds: h * 3600 + m * 60 + s)
        editingElapsed = false
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        SectionCard(title: "Timeline", icon: "calendar") {
            VStack(alignment: .leading, spacing: 8) {
                if editingTimeline {
                    HStack(spacing: 8) {
                        Text("Start")
                            .font(.system(size: 11))
                            .frame(width: 80, alignment: .leading)
                        DatePicker("", selection: $timelineStart, displayedComponents: .date)
                            .labelsHidden()
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        Toggle("Estimated end", isOn: $timelineHasEnd)
                            .font(.system(size: 11))
                            .toggleStyle(.checkbox)
                        Spacer()
                        if timelineHasEnd {
                            DatePicker("", selection: $timelineEnd, in: timelineStart..., displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            editingTimeline = false
                            timelineStart = goal.startDate
                            timelineEnd = goal.estimatedEndDate ?? Date()
                            timelineHasEnd = goal.estimatedEndDate != nil
                        }
                        .controlSize(.small)
                        Button("Save") {
                            goalVM.updateTimeline(goal, startDate: timelineStart, estimatedEndDate: timelineHasEnd ? timelineEnd : nil)
                            editingTimeline = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.calmTeal)
                        .controlSize(.small)
                    }
                } else {
                    HStack(spacing: 16) {
                        TimelinePoint(label: "Start", date: goal.startDate, accent: Color.calmTeal)
                        TimelinePoint(
                            label: "Estimated End",
                            date: goal.estimatedEndDate,
                            accent: Color.calmBlue
                        )
                        if let completed = goal.completedAt {
                            TimelinePoint(label: "Completed", date: completed, accent: .green)
                        }
                        Spacer()
                        Button("Edit") { editingTimeline = true }
                            .font(.system(size: 11))
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.calmTeal)
                    }
                }
            }
        }
    }

    // MARK: - Milestones

    private var milestonesSection: some View {
        SectionCard(title: "Milestones", icon: "flag.fill") {
            VStack(alignment: .leading, spacing: 6) {
                if goal.milestones.isEmpty {
                    Text("Optional. Break this goal into steps and check them off as you go.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(goal.milestones.sorted(by: { $0.position < $1.position })) { milestone in
                        MilestoneRow(goal: goal, milestone: milestone)
                            .environmentObject(goalVM)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.calmTeal)
                    TextField("Add a step toward this goal…", text: $newMilestoneTitle, onCommit: addMilestone)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .onSubmit(addMilestone)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)
            }
        }
    }

    private func addMilestone() {
        let trimmed = newMilestoneTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        goalVM.addMilestone(goal, title: trimmed)
        newMilestoneTitle = ""
    }

    // MARK: - Notes

    private var notesSection: some View {
        SectionCard(title: "Notes & Resources", icon: "doc.text") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Day-by-day notes, links, references — anything you want to remember about this goal.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                TextEditor(text: $editingNotes)
                    .font(.system(size: 12))
                    .frame(minHeight: 120)
                    .padding(6)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(6)
                    .onChange(of: editingNotes) { _, newValue in
                        // Debounced-ish: just save on changes; Firestore will coalesce.
                        if newValue != goal.notes {
                            goalVM.updateNotes(goal, notes: newValue)
                        }
                    }
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        SectionCard(title: "Goal Stats", icon: "chart.bar.xaxis") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 16) {
                    StatTile(
                        label: "Total time",
                        value: Goal.formatElapsedLong(goal.totalElapsedSeconds),
                        accent: Color.calmTeal
                    )
                    if let actual = goal.actualDurationDays {
                        StatTile(
                            label: "Actual duration",
                            value: "\(actual) day\(actual == 1 ? "" : "s")",
                            accent: Color.calmBlue
                        )
                    }
                    if let estimated = goal.estimatedDurationDays {
                        StatTile(
                            label: "Estimated",
                            value: "\(estimated) day\(estimated == 1 ? "" : "s")",
                            accent: .secondary
                        )
                    }
                }

                if let delta = goal.dayDelta {
                    Label(deltaLabel(delta), systemImage: delta <= 0 ? "checkmark.circle" : "clock.badge.exclamationmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(deltaColor(delta))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Timeline")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(Self.dayFormatter.string(from: goal.startDate))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        if let est = goal.estimatedEndDate {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                            Text("est. \(Self.dayFormatter.string(from: est))")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        if let done = goal.completedAt {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                            Text("done \(Self.dayFormatter.string(from: done))")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private func deltaLabel(_ delta: Int) -> String {
        if delta == 0 { return "Right on schedule" }
        if delta < 0 { return "Finished \(-delta) day\(delta == -1 ? "" : "s") early" }
        return "Finished \(delta) day\(delta == 1 ? "" : "s") later than expected"
    }

    private func deltaColor(_ delta: Int) -> Color {
        delta <= 0 ? .green : .orange
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        HStack {
            Spacer()
            Button(role: .destructive, action: { showingDeleteConfirm = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                    Text("Delete Goal")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Subviews

private struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.calmTeal)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.7))
            }
            content()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }
}

private struct TimelinePoint: View {
    let label: String
    let date: Date?
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(accent).frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            if let date = date {
                Text(date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.system(size: 12, weight: .semibold))
            } else {
                Text("—")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct StatTile: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(accent == .secondary ? .primary : accent)
        }
        .padding(10)
        .frame(minWidth: 100, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }
}

private struct EditElapsedSheet: View {
    @Binding var isPresented: Bool
    @Binding var hours: String
    @Binding var minutes: String
    @Binding var seconds: String
    var onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit Total Time")
                .font(.system(size: 16, weight: .bold))
            Text("Honor system — set this to the time you've actually spent on this goal.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TimeField(label: "Hours", text: $hours)
                Text(":").font(.title2).foregroundStyle(.secondary)
                TimeField(label: "Minutes", text: $minutes)
                Text(":").font(.title2).foregroundStyle(.secondary)
                TimeField(label: "Seconds", text: $seconds)
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Save") { onSave() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.calmTeal)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}

private struct TimeField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("0", text: $text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .frame(width: 60)
                .onChange(of: text) { _, newValue in
                    text = newValue.filter(\.isNumber)
                }
        }
    }
}
