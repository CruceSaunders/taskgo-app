import SwiftUI

struct AddTaskView: View {
    @EnvironmentObject var taskVM: TaskViewModel
    @Environment(\.dismiss) var dismiss

    let groupId: String

    @State private var name = ""
    @State private var hours = 0
    @State private var minutes = 25
    @State private var description = ""
    @State private var position = ""
    @State private var showDescription = false
    @State private var showPosition = false

    var timeEstimateSeconds: Int {
        (hours * 3600) + (minutes * 60)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("New Task")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Task name
            TextField("Task name", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))

            // Time estimate
            VStack(alignment: .leading, spacing: 4) {
                Text("Time estimate")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Picker("Hours", selection: $hours) {
                            ForEach(0..<13) { h in
                                Text("\(h)h").tag(h)
                            }
                        }
                        .frame(width: 60)
                    }

                    HStack(spacing: 4) {
                        Picker("Minutes", selection: $minutes) {
                            ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                                Text("\(m)m").tag(m)
                            }
                        }
                        .frame(width: 60)
                    }
                }
            }

            // Optional fields toggles
            HStack(spacing: 12) {
                Button(action: { showDescription.toggle() }) {
                    Label("Note", systemImage: "doc.text")
                        .font(.system(size: 11))
                        .foregroundStyle(showDescription ? Color.calmTeal : .secondary)
                }
                .buttonStyle(.plain)

                Button(action: { showPosition.toggle() }) {
                    Label("Position", systemImage: "number")
                        .font(.system(size: 11))
                        .foregroundStyle(showPosition ? Color.calmTeal : .secondary)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            // Description field (optional)
            if showDescription {
                TextEditor(text: $description)
                    .font(.system(size: 12))
                    .frame(height: 60)
                    .border(Color.secondary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Position field (optional)
            if showPosition {
                HStack {
                    Text("Position in list:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField("#", text: $position)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                }
            }

            // Add button
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
                    dismiss()
                }
            }) {
                Text("Add Task")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.calmTeal)
            .disabled(name.isEmpty || timeEstimateSeconds == 0)
        }
        .padding(16)
        .frame(width: 300)
    }
}
