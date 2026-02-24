import SwiftUI

struct TimerWidgetView: View {
    @EnvironmentObject var taskGoVM: TaskGoViewModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(taskGoVM.lanes.enumerated()), id: \.element.id) { index, lane in
                if index > 0 {
                    Divider().padding(.horizontal, 6)
                }
                LaneRowView(lane: lane, taskGoVM: taskGoVM)
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        )
        .frame(width: 200)
    }
}

struct LaneRowView: View {
    @ObservedObject var lane: TaskGoLane
    var taskGoVM: TaskGoViewModel

    private var laneColor: Color { Color(lane.color) }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Circle()
                    .fill(laneColor)
                    .frame(width: 6, height: 6)

                if let task = lane.currentTask {
                    if task.isChained {
                        Image(systemName: "link")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                        if let order = task.chainOrder, let chainId = task.chainId {
                            let total = taskGoVM.taskVM?.tasksInChain(chainId).count ?? 0
                            Text("\(order)/\(total)")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                    } else if task.isBatched {
                        Image(systemName: "square.stack")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.calmTeal)
                    }

                    Text(task.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 2)

                if taskGoVM.lanes.count > 1 {
                    Button(action: { taskGoVM.removeLane(lane) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(lane.timeRemainingFormatted)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(lane.isExpired ? Color.amberText : Color.primary)
                .frame(maxWidth: .infinity)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(lane.isExpired ? Color.amber : laneColor)
                        .frame(width: geometry.size.width * lane.progress, height: 3)
                        .animation(.linear(duration: 1), value: lane.progress)
                }
            }
            .frame(height: 3)

            HStack(spacing: 8) {
                if lane.isExpired {
                    Button(action: { taskGoVM.addMoreTime(300, lane: lane) }) {
                        Label("+5m", systemImage: "clock.arrow.circlepath")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button(action: { taskGoVM.completeAndAdvance(lane: lane) }) {
                        Label("Done", systemImage: "checkmark")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                } else {
                    Button(action: { taskGoVM.togglePause(lane: lane) }) {
                        Label(
                            lane.state == .paused ? "Resume" : "Pause",
                            systemImage: lane.state == .paused ? "play.fill" : "pause.fill"
                        )
                        .font(.system(size: 9, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button(action: { taskGoVM.completeAndAdvance(lane: lane) }) {
                        Label("Done", systemImage: "checkmark")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(lane.isExpired ? Color.amberBackground.opacity(0.5) : Color.clear)
    }
}

// MARK: - Custom Colors

extension Color {
    static let amber = Color(red: 0.95, green: 0.76, blue: 0.19)
    static let amberBackground = Color(red: 0.98, green: 0.94, blue: 0.82)
    static let amberText = Color(red: 0.72, green: 0.52, blue: 0.04)
    static let calmBlue = Color(red: 0.34, green: 0.62, blue: 0.82)
    static let calmTeal = Color(red: 0.27, green: 0.71, blue: 0.67)
}

// MARK: - Task Go Notification

extension Notification.Name {
    static let taskGoCompleteTask = Notification.Name("taskGoCompleteTask")
}
