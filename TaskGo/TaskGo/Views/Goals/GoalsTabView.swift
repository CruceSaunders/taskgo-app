import SwiftUI

struct GoalsTabView: View {
    @EnvironmentObject var goalVM: GoalViewModel

    @State private var newGoalTitle: String = ""
    @State private var showingCompleted: Bool = false
    @State private var showingNewGoalSheet: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if goalVM.goals.isEmpty {
                emptyState
            } else if let goal = goalVM.selectedGoal {
                GoalDetailView(goal: goal)
            } else {
                goalList
            }
        }
        .onAppear { goalVM.startListening() }
        .sheet(isPresented: $showingNewGoalSheet) {
            NewGoalSheet(isPresented: $showingNewGoalSheet)
                .environmentObject(goalVM)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if goalVM.selectedGoal != nil {
                Button(action: { goalVM.selectedGoalId = nil }) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Goals")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color.calmTeal)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .foregroundStyle(Color.calmTeal)
                    Text("Goals")
                        .font(.system(size: 13, weight: .semibold))
                }
            }

            Spacer()

            if goalVM.selectedGoal == nil && !goalVM.goals.isEmpty {
                Picker("", selection: $showingCompleted) {
                    Text("Active").tag(false)
                    Text("Completed").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)
                .controlSize(.small)
            }

            if goalVM.selectedGoal == nil {
                Button(action: { showingNewGoalSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text("New")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.calmTeal)
                    .foregroundStyle(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "target")
                .font(.system(size: 40))
                .foregroundStyle(Color.calmTeal.opacity(0.5))
            Text("No goals yet")
                .font(.system(size: 14, weight: .semibold))
            Text("Create a goal to start tracking progress, milestones, and the time you spend on it.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Create Your First Goal") {
                showingNewGoalSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.calmTeal)
            .controlSize(.regular)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var goalList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                let visible = showingCompleted ? goalVM.completedGoals : goalVM.activeGoals
                if visible.isEmpty {
                    Text(showingCompleted ? "No completed goals yet." : "No active goals.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.top, 32)
                } else {
                    ForEach(visible) { goal in
                        GoalListRow(goal: goal)
                            .onTapGesture {
                                goalVM.selectedGoalId = goal.id
                            }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Row

private struct GoalListRow: View {
    @EnvironmentObject var goalVM: GoalViewModel
    let goal: Goal

    @State private var hovered = false

    var body: some View {
        let _ = goalVM.stopwatchTick // ensure re-render while running
        let running = goal.isStopwatchRunning && !goal.isCompleted
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: goal.progressFraction)
                    .stroke(Color.calmTeal, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(goal.progressFraction * 100))%")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.7))
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(goal.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if goal.isCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                    }
                }
                HStack(spacing: 6) {
                    if !goal.milestones.isEmpty {
                        Label("\(goal.completedMilestoneCount)/\(goal.milestones.count)", systemImage: "flag")
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Label(Goal.formatElapsedLong(goalVM.liveElapsedSeconds(goal)),
                          systemImage: "stopwatch")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    if running {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                    }
                }
            }

            Spacer()

            if !goal.isCompleted {
                Button(action: { goalVM.toggleStopwatch(goal) }) {
                    Image(systemName: running ? "pause.fill" : "play.fill")
                        .font(.system(size: 11))
                        .frame(width: 28, height: 28)
                        .background(running ? Color.red.opacity(0.85) : Color.calmTeal)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(running ? "Pause stopwatch" : "Start stopwatch")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(hovered ? Color.secondary.opacity(0.08) : Color.secondary.opacity(0.03))
        .cornerRadius(8)
        .onHover { hovered = $0 }
    }
}

// MARK: - New Goal Sheet

private struct NewGoalSheet: View {
    @EnvironmentObject var goalVM: GoalViewModel
    @Binding var isPresented: Bool

    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var hasEstimate: Bool = false
    @State private var estimatedEndDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Goal")
                .font(.system(size: 16, weight: .bold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("What do you want to accomplish?", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Timeline")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Start")
                        .font(.system(size: 11))
                        .frame(width: 80, alignment: .leading)
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                    Spacer()
                }

                HStack {
                    Toggle("Estimated end", isOn: $hasEstimate)
                        .font(.system(size: 11))
                        .toggleStyle(.checkbox)
                    Spacer()
                    if hasEstimate {
                        DatePicker("", selection: $estimatedEndDate, in: startDate..., displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Create") {
                    goalVM.createGoal(
                        title: title,
                        startDate: startDate,
                        estimatedEndDate: hasEstimate ? estimatedEndDate : nil
                    )
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.calmTeal)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
