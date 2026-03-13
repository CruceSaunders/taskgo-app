import SwiftUI

struct PomodoroWidgetView: View {
    @EnvironmentObject var pomodoroVM: PomodoroViewModel

    private var sessionColor: Color {
        pomodoroVM.sessionType == .work ? .pomodoroRed : .calmTeal
    }

    var body: some View {
        VStack(spacing: 8) {
            // Session label + pomodoro dots
            HStack(spacing: 4) {
                Image(systemName: pomodoroVM.sessionType == .work ? "flame.fill" : "cup.and.saucer.fill")
                    .font(.system(size: 9))
                Text(pomodoroVM.sessionType.rawValue)
                    .font(.system(size: 10, weight: .semibold))

                Spacer(minLength: 2)

                if pomodoroVM.completedPomodoros > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(pomodoroVM.completedPomodoros, 8), id: \.self) { _ in
                            Circle()
                                .fill(Color.pomodoroRed)
                                .frame(width: 5, height: 5)
                        }
                        if pomodoroVM.completedPomodoros > 8 {
                            Text("+\(pomodoroVM.completedPomodoros - 8)")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .foregroundStyle(sessionColor)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Timer
            Text(pomodoroVM.formattedTime)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(pomodoroVM.isPaused ? .secondary : .primary)
                .frame(maxWidth: .infinity)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(sessionColor)
                        .frame(width: geo.size.width * pomodoroVM.progress, height: 3)
                        .animation(.linear(duration: 1), value: pomodoroVM.progress)
                }
            }
            .frame(height: 3)

            if pomodoroVM.isPaused {
                Text("PAUSED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            // Controls
            HStack(spacing: 8) {
                Button(action: { pomodoroVM.togglePause() }) {
                    Label(
                        pomodoroVM.isPaused ? "Resume" : "Pause",
                        systemImage: pomodoroVM.isPaused ? "play.fill" : "pause.fill"
                    )
                    .font(.system(size: 9, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button(action: { pomodoroVM.stop() }) {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(.red)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        )
        .frame(width: 200)
    }
}
