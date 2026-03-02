import SwiftUI

struct PlanDetailView: View {
    @EnvironmentObject var plannerVM: PlannerViewModel
    @State private var confirmDelete = false

    var body: some View {
        if let plan = plannerVM.selectedPlan {
            VStack(spacing: 0) {
                planHeader(plan)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        overallSection(plan)
                        dailySections(plan)
                    }
                    .padding(.bottom, 16)
                }
            }
        } else {
            emptyState
        }
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
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(Color.calmTeal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.calmTeal.opacity(0.12))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: { plannerVM.completePlan() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 9))
                                Text("Complete")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
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
                    onDelete: { plannerVM.removeObjective(objectiveId: obj.id, date: nil) }
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
                        onDelete: { plannerVM.removeObjective(objectiveId: obj.id, date: dateStr) }
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

    @State private var isEditing = false
    @State private var editText = ""
    @State private var isHovering = false

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
