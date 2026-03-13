import SwiftUI

struct PomodoroPopupView: View {
    @EnvironmentObject var pomodoroVM: PomodoroViewModel

    var body: some View {
        VStack(spacing: 16) {
            header
            timerRing
            controls
        }
        .padding(20)
        .frame(width: 260)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: pomodoroVM.sessionType == .work ? "flame.fill" : "cup.and.saucer.fill")
                    .font(.system(size: 12))
                Text(pomodoroVM.sessionType.rawValue)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(pomodoroVM.sessionType == .work ? Color.pomodoroRed : Color.calmTeal)

            Spacer()

            if pomodoroVM.completedPomodoros > 0 {
                HStack(spacing: 3) {
                    ForEach(0..<pomodoroVM.completedPomodoros, id: \.self) { _ in
                        Circle()
                            .fill(Color.pomodoroRed)
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
    }

    // MARK: - Timer Ring

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 6)

            Circle()
                .trim(from: 0, to: pomodoroVM.progress)
                .stroke(
                    pomodoroVM.sessionType == .work ? Color.pomodoroRed : Color.calmTeal,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: pomodoroVM.progress)

            VStack(spacing: 2) {
                Text(pomodoroVM.formattedTime)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))

                if pomodoroVM.isPaused {
                    Text("PAUSED")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 150, height: 150)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: { pomodoroVM.togglePause() }) {
                HStack(spacing: 4) {
                    Image(systemName: pomodoroVM.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 11))
                    Text(pomodoroVM.isPaused ? "Resume" : "Pause")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(7)
            }
            .buttonStyle(.plain)

            Button(action: { pomodoroVM.stop() }) {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11))
                    Text("Stop")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.red.opacity(0.12))
                .foregroundStyle(.red)
                .cornerRadius(7)
            }
            .buttonStyle(.plain)
        }
    }
}
