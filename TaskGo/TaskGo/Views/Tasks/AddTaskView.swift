import SwiftUI

struct AddTaskView: View {
    @EnvironmentObject var taskVM: TaskViewModel

    let groupId: String
    var onDismiss: () -> Void

    @State private var name = ""
    @State private var minutesText = "25"
    @State private var description = ""
    @State private var position = ""
    @State private var showDescription = false
    @State private var showPosition = false

    var timeEstimateSeconds: Int {
        (Int(minutesText) ?? 0) * 60
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("New Task")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { onDismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Task name
            TextField("Task name", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            // Time estimate
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

                // Optional field toggles
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

            // Description field (optional)
            if showDescription {
                TextField("Add a note...", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }

            // Position field (optional)
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
        .padding(14)
    }
}
