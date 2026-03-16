import SwiftUI

struct ActivitySummaryView: View {
    @EnvironmentObject var activityVM: ActivityViewModel

    var body: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "Active Time",
                value: activityVM.totalActiveTime,
                icon: "clock.fill",
                color: .calmTeal
            )
            summaryCard(
                title: "Keystrokes",
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

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 10_000 {
            return String(format: "%.1fk", Double(n) / 1000)
        }
        return "\(n)"
    }
}
