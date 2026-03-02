import SwiftUI

struct AddTaskView: View {
    @EnvironmentObject var taskVM: TaskViewModel

    let groupId: String
    var onDismiss: () -> Void

    enum AddMode: String { case single, batch, chain }
    @State private var mode: AddMode = .single

    // Single task fields
    @State private var name = ""
    @State private var minutesText = ""
    @State private var description = ""
    @State private var position = ""
    @State private var showDescription = false
    @State private var showPosition = false
    @State private var showRecurrence = false
    @State private var recFrequency = "daily"
    @State private var recInterval = "1"
    @State private var recDaysOfWeek: Set<Int> = []
    @State private var recTimes: [String] = ["09:00"]
    @State private var recHasEndDate = false
    @State private var recEndDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    // Batch fields
    @State private var batchTitle = ""
    @State private var batchNames: [String] = ["", ""]
    @State private var batchMinutesText = "30"

    // Chain fields
    @State private var chainTitle = ""
    @State private var chainNames: [String] = ["", ""]
    @State private var chainMinutes: [String] = ["25", "25"]

    var timeEstimateSeconds: Int {
        (Int(minutesText) ?? 0) * 60
    }

    var batchTimeSeconds: Int {
        (Int(batchMinutesText) ?? 0) * 60
    }

    var body: some View {
        VStack(spacing: 10) {
            // Header with mode toggles
            HStack(spacing: 6) {
                Text(mode == .single ? "New Task" : mode == .batch ? "New Batch" : "New Chain")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()

                Button(action: { onDismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Mode selector with labels
            HStack(spacing: 4) {
                modeTab("Single", icon: "circle", target: .single, color: Color.calmTeal)
                modeTab("Batch", icon: "square.stack", target: .batch, color: Color.calmTeal)
                modeTab("Chain", icon: "link", target: .chain, color: .orange)
            }

            switch mode {
            case .single: singleTaskView
            case .batch: batchModeView
            case .chain: chainModeView
            }
        }
        .padding(14)
    }

    private func modeTab(_ label: String, icon: String, target: AddMode, color: Color) -> some View {
        Button(action: { mode = target }) {
            HStack(spacing: 3) {
                Image(systemName: mode == target ? "\(icon).fill" : icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 10, weight: mode == target ? .semibold : .regular))
            }
            .foregroundStyle(mode == target ? .white : .primary.opacity(0.5))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(mode == target ? color : Color.secondary.opacity(0.08))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Single Task

    private var singleTaskView: some View {
        VStack(spacing: 10) {
            TextField("Task name", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            HStack(spacing: 6) {
                Text("Time")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.55))

                TextField("optional", text: $minutesText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 55)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)

                Text("min")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.55))

                Spacer()

                Button(action: { showDescription.toggle() }) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                        .foregroundStyle(showDescription ? Color.calmTeal : .primary.opacity(0.4))
                }
                .buttonStyle(.plain)

                Button(action: { showPosition.toggle() }) {
                    Image(systemName: "number")
                        .font(.system(size: 11))
                        .foregroundStyle(showPosition ? Color.calmTeal : .primary.opacity(0.4))
                }
                .buttonStyle(.plain)

                Button(action: { showRecurrence.toggle() }) {
                    Image(systemName: "repeat")
                        .font(.system(size: 11))
                        .foregroundStyle(showRecurrence ? Color.calmTeal : .primary.opacity(0.4))
                }
                .buttonStyle(.plain)
            }

            if showDescription {
                TextField("Add a note...", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }

            if showPosition {
                HStack {
                    Text("Position:")
                        .font(.system(size: 11))
                        .foregroundStyle(.primary.opacity(0.55))
                    TextField("#", text: $position)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .font(.system(size: 12))
                }
            }

            if showRecurrence {
                recurrenceSection
            }

            Button(action: {
                let positionInt = Int(position)
                let time = minutesText.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : timeEstimateSeconds
                let rule: RecurrenceRule? = showRecurrence ? buildRecurrenceRule() : nil
                Task {
                    await taskVM.addTask(
                        name: name,
                        timeEstimate: time,
                        description: showDescription && !description.isEmpty ? description : nil,
                        position: showPosition ? positionInt : nil,
                        groupId: groupId,
                        recurrence: rule
                    )
                    onDismiss()
                }
            }) {
                Text(showRecurrence ? "Add Recurring Task" : "Add Task")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.calmTeal)
            .disabled(name.isEmpty)
        }
    }

    // MARK: - Recurrence

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "repeat")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.calmTeal)
                Text("Repeat")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.calmTeal)
            }

            HStack(spacing: 6) {
                ForEach(["daily", "weekly", "custom"], id: \.self) { freq in
                    Button(action: { recFrequency = freq }) {
                        Text(freq.capitalized)
                            .font(.system(size: 10, weight: recFrequency == freq ? .semibold : .regular))
                            .foregroundStyle(recFrequency == freq ? .white : .primary.opacity(0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(recFrequency == freq ? Color.calmTeal : Color.secondary.opacity(0.08))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 4) {
                Text("Every")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.55))
                TextField("1", text: $recInterval)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 30)
                    .font(.system(size: 10))
                    .multilineTextAlignment(.center)
                Text(recFrequency == "weekly" ? "week(s)" : "day(s)")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.55))
            }

            if recFrequency == "weekly" || recFrequency == "custom" {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Days")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.55))
                    HStack(spacing: 3) {
                        ForEach([(1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")], id: \.0) { day, label in
                            Button(action: {
                                if recDaysOfWeek.contains(day) {
                                    recDaysOfWeek.remove(day)
                                } else {
                                    recDaysOfWeek.insert(day)
                                }
                            }) {
                                Text(label)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(recDaysOfWeek.contains(day) ? .white : .primary.opacity(0.5))
                                    .frame(width: 22, height: 22)
                                    .background(recDaysOfWeek.contains(day) ? Color.calmTeal : Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Times")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.55))
                    Spacer()
                    Button(action: { recTimes.append("09:00") }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.calmTeal)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(recTimes.indices, id: \.self) { index in
                    HStack(spacing: 4) {
                        TextField("HH:mm", text: $recTimes[index])
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .font(.system(size: 10))
                            .multilineTextAlignment(.center)
                        if recTimes.count > 1 {
                            Button(action: { recTimes.remove(at: index) }) {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 4) {
                Toggle("End date", isOn: $recHasEndDate)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.55))
                if recHasEndDate {
                    DatePicker("", selection: $recEndDate, displayedComponents: .date)
                        .labelsHidden()
                        .controlSize(.small)
                }
            }
        }
        .padding(8)
        .background(Color.calmTeal.opacity(0.05))
        .cornerRadius(8)
    }

    private func buildRecurrenceRule() -> RecurrenceRule {
        RecurrenceRule(
            frequency: recFrequency,
            interval: Int(recInterval) ?? 1,
            daysOfWeek: (recFrequency == "weekly" || recFrequency == "custom") && !recDaysOfWeek.isEmpty ? Array(recDaysOfWeek) : nil,
            timesOfDay: recTimes.filter { !$0.isEmpty },
            endDate: recHasEndDate ? recEndDate : nil
        )
    }

    // MARK: - Batch Mode

    private var batchModeView: some View {
        VStack(spacing: 10) {
            // Batch title
            TextField("Batch title (e.g. Morning Routine)", text: $batchTitle)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            // Sub-task name fields
            ForEach(batchNames.indices, id: \.self) { index in
                HStack(spacing: 6) {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    TextField("Task name", text: $batchNames[index])
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    if batchNames.count > 2 {
                        Button(action: { batchNames.remove(at: index) }) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(.red.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Add another sub-task
            Button(action: { batchNames.append("") }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 10))
                    Text("Add sub-task")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color.calmTeal)
            }
            .buttonStyle(.plain)

            // Collective time
            HStack(spacing: 6) {
                Text("Batch time")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.55))

                TextField("30", text: $batchMinutesText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)

                Text("min total")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.55))

                Spacer()
            }

            // Create batch
            Button(action: {
                let validNames = batchNames.filter { !$0.isEmpty }
                guard !validNames.isEmpty else { return }
                Task {
                    await taskVM.addBatch(
                        names: validNames,
                        batchTimeEstimate: batchTimeSeconds,
                        groupId: groupId,
                        title: batchTitle.isEmpty ? nil : batchTitle
                    )
                    onDismiss()
                }
            }) {
                Text("Create Batch (\(batchNames.filter { !$0.isEmpty }.count) tasks)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.calmTeal)
            .disabled(batchNames.filter { !$0.isEmpty }.count < 2 || batchTimeSeconds == 0)
        }
    }

    // MARK: - Chain Mode

    private var chainModeView: some View {
        VStack(spacing: 10) {
            // Chain title
            TextField("Chain title (e.g. Deploy Pipeline)", text: $chainTitle)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            ForEach(chainNames.indices, id: \.self) { index in
                HStack(spacing: 6) {
                    Text("Step \(index + 1)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.orange)
                        .frame(width: 38)

                    TextField("Task name", text: $chainNames[index])
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    TextField("min", text: $chainMinutes[index])
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 36)
                        .font(.system(size: 11))
                        .multilineTextAlignment(.center)

                    if chainNames.count > 2 {
                        Button(action: {
                            chainNames.remove(at: index)
                            chainMinutes.remove(at: index)
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(.red.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(action: {
                chainNames.append("")
                chainMinutes.append("25")
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 10))
                    Text("Add step")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)

            let validCount = chainNames.filter { !$0.isEmpty }.count

            Button(action: {
                var names: [String] = []
                var times: [Int] = []
                for (i, n) in chainNames.enumerated() {
                    guard !n.isEmpty else { continue }
                    names.append(n)
                    times.append((Int(chainMinutes[i]) ?? 25) * 60)
                }
                Task {
                    await taskVM.addChain(names: names, times: times, groupId: groupId, title: chainTitle.isEmpty ? nil : chainTitle)
                    onDismiss()
                }
            }) {
                Text("Create Chain (\(validCount) steps)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(validCount < 2)
        }
    }
}
