import SwiftUI

struct ActivitySummaryView: View {
    @EnvironmentObject var activityVM: ActivityViewModel

    var body: some View {
        VStack(spacing: 8) {
            if activityVM.hasAppTrackingData {
                productivityCards
            }
            inputCards
        }
    }

    private var productivityCards: some View {
        HStack(spacing: 8) {
            summaryCard(
                title: "Pulse",
                value: String(format: "%.0f", activityVM.productivityPulse),
                icon: "gauge.high",
                color: pulseColor(activityVM.productivityPulse)
            )
            summaryCard(
                title: "Productive",
                value: activityVM.productiveTimeString,
                icon: "checkmark.circle.fill",
                color: .green
            )
            summaryCard(
                title: "Neutral",
                value: activityVM.neutralTimeString,
                icon: "minus.circle.fill",
                color: .gray
            )
            summaryCard(
                title: "Distracting",
                value: activityVM.distractingTimeString,
                icon: "xmark.circle.fill",
                color: .red
            )
        }
    }

    private var inputCards: some View {
        HStack(spacing: 8) {
            summaryCard(
                title: "Active",
                value: activityVM.totalActiveTime,
                icon: "clock.fill",
                color: .calmTeal
            )
            summaryCard(
                title: "Keys",
                value: formatNumber(activityVM.totalKeystrokes),
                icon: "keyboard",
                color: .blue
            )
            summaryCard(
                title: "Clicks",
                value: formatNumber(activityVM.totalClicks),
                icon: "cursorarrow.click.2",
                color: .green
            )
            summaryCard(
                title: "Avg/min",
                value: "\(activityVM.averageInputsPerActiveMinute)",
                icon: "gauge.medium",
                color: .orange
            )
        }
    }

    private func pulseColor(_ pulse: Double) -> Color {
        if pulse >= 75 { return .green }
        if pulse >= 50 { return .calmTeal }
        if pulse >= 25 { return .orange }
        return .red
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.06))
        .cornerRadius(6)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 10_000 {
            return String(format: "%.1fk", Double(n) / 1000)
        }
        return "\(n)"
    }
}
