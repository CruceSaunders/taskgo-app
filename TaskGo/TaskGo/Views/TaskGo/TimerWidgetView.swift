import SwiftUI

struct TimerWidgetView: View {
    @EnvironmentObject var taskGoVM: TaskGoViewModel

    var body: some View {
        VStack(spacing: 8) {
            // Task name / batch label / chain step
            if let task = taskGoVM.currentTask {
                HStack(spacing: 4) {
                    if task.isChained {
                        Image(systemName: "link")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                        if let order = task.chainOrder, let chainId = task.chainId {
                            let total = taskGoVM.taskVM?.tasksInChain(chainId).count ?? 0
                            Text("Step \(order)/\(total)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                        Text(task.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else if task.isBatched {
                        Image(systemName: "square.stack")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.calmTeal)
                        Text("Batch")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(task.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Countdown timer (hero element)
            Text(taskGoVM.timeRemainingFormatted)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(taskGoVM.isExpired ? Color.amberText : Color.primary)
                .frame(maxWidth: .infinity)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(taskGoVM.isExpired ? Color.amber : Color.accentColor)
                        .frame(width: geometry.size.width * taskGoVM.progress, height: 4)
                        .animation(.linear(duration: 1), value: taskGoVM.progress)
                }
            }
            .frame(height: 4)

            // Action buttons
            HStack(spacing: 12) {
                if taskGoVM.isExpired {
                    // Expired: +5 min and Done
                    Button(action: {
                        taskGoVM.addMoreTime(300) // 5 minutes
                    }) {
                        Label("+5 min", systemImage: "clock.arrow.circlepath")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: {
                        taskGoVM.completeAndAdvance()
                    }) {
                        Label("Done", systemImage: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    // Running/Paused: Pause/Resume and Done
                    Button(action: {
                        taskGoVM.togglePause()
                    }) {
                        Label(
                            taskGoVM.state == .paused ? "Resume" : "Pause",
                            systemImage: taskGoVM.state == .paused ? "play.fill" : "pause.fill"
                        )
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: {
                        taskGoVM.completeAndAdvance()
                    }) {
                        Label("Done", systemImage: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(taskGoVM.isExpired ? Color.amberBackground : Color(.windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        )
        .frame(width: 170, height: 100)
    }
}

// MARK: - Task Go Notification

extension Notification.Name {
    static let taskGoCompleteTask = Notification.Name("taskGoCompleteTask")
}

// MARK: - Custom Colors

extension Color {
    static let amber = Color(red: 0.95, green: 0.76, blue: 0.19)
    static let amberBackground = Color(red: 0.98, green: 0.94, blue: 0.82)
    static let amberText = Color(red: 0.72, green: 0.52, blue: 0.04)
    static let calmBlue = Color(red: 0.34, green: 0.62, blue: 0.82)
    static let calmTeal = Color(red: 0.27, green: 0.71, blue: 0.67)
}
