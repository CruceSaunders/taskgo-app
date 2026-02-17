import SwiftUI

struct AddTaskView: View {
    @EnvironmentObject var taskVM: TaskViewModel

    let groupId: String
    var onDismiss: () -> Void

    enum AddMode: String { case single, batch, chain }
    @State private var mode: AddMode = .single

    // Single task fields
    @State private var name = ""
    @State private var minutesText = "25"
    @State private var description = ""
    @State private var position = ""
    @State private var showDescription = false
    @State private var showPosition = false

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

                TextField("25", text: $minutesText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
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

            Button(action: {
                let positionInt = Int(position)
                Task {
                    await taskVM.addTask(
                        name: name,
                        timeEstimate: timeEstimateSeconds,
                        description: showDescription && !description.isEmpty ? description : nil,
                        position: showPosition ? positionInt : nil,
                        groupId: groupId
                    )
                    onDismiss()
                }
            }) {
                Text("Add Task")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.calmTeal)
            .disabled(name.isEmpty || timeEstimateSeconds == 0)
        }
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
