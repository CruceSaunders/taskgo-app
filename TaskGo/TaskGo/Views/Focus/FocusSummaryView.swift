import SwiftUI

struct FocusSummaryView: View {
    let summary: FocusSessionSummary
    @EnvironmentObject var focusVM: FocusGuardViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(scoreColor)

                Text("Focus Session Complete")
                    .font(.system(size: 13, weight: .semibold))

                Text(summary.taskName)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                HStack(spacing: 20) {
                    summaryItem(value: String(format: "%.0f%%", summary.focusScore), label: "Focus Score")
                    summaryItem(value: formattedDuration, label: "Duration")
                }

                HStack(spacing: 16) {
                    summaryItem(value: "\(summary.totalChecks)", label: "Checks")
                    summaryItem(value: "\(summary.onTaskChecks)", label: "On Task")
                    summaryItem(value: "\(summary.notifications)", label: "Alerts")
                }

                Button(action: { focusVM.dismissSummary() }) {
                    Text("Done")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 6)
                        .background(Color.calmTeal)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(.regularMaterial)
            .cornerRadius(12)
            .shadow(radius: 10)
            .frame(maxWidth: 280)
        }
    }

    private func summaryItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold).monospacedDigit())
                .foregroundStyle(.primary.opacity(0.8))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.primary.opacity(0.4))
        }
    }

    private var formattedDuration: String {
        let h = summary.duration / 3600
        let m = (summary.duration % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private var scoreColor: Color {
        if summary.focusScore >= 80 { return .green }
        if summary.focusScore >= 50 { return .orange }
        return .red
    }
}
