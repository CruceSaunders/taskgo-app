import SwiftUI

struct ActivitySummaryView: View {
    @EnvironmentObject var activityVM: ActivityViewModel
    var isCompact: Bool = false

    var body: some View {
        VStack(spacing: isCompact ? 6 : 8) {
            if activityVM.hasAppTrackingData {
                if isCompact {
                    compactProductivityCards
                } else {
                    wideProductivityCards
                }
            }
            if isCompact {
                compactInputCards
            } else {
                wideInputCards
            }
        }
    }

    // MARK: - Wide Layout (window view)

    private var wideProductivityCards: some View {
        HStack(spacing: 8) {
            summaryCard(title: "Pulse", value: String(format: "%.0f", activityVM.productivityPulse),
                        icon: "gauge.high", color: pulseColor(activityVM.productivityPulse))
            summaryCard(title: "Productive", value: activityVM.productiveTimeString,
                        icon: "checkmark.circle.fill", color: .green)
            summaryCard(title: "Neutral", value: activityVM.neutralTimeString,
                        icon: "minus.circle.fill", color: .gray)
            summaryCard(title: "Distracting", value: activityVM.distractingTimeString,
                        icon: "xmark.circle.fill", color: .red)
        }
    }

    private var wideInputCards: some View {
        HStack(spacing: 8) {
            summaryCard(title: "Active", value: activityVM.totalActiveTime,
                        icon: "clock.fill", color: .calmTeal)
            summaryCard(title: "Keys", value: formatNumber(activityVM.totalKeystrokes),
                        icon: "keyboard", color: .blue)
            summaryCard(title: "Clicks", value: formatNumber(activityVM.totalClicks),
                        icon: "cursorarrow.click.2", color: .green)
            summaryCard(title: "Avg/min", value: "\(activityVM.averageInputsPerActiveMinute)",
                        icon: "gauge.medium", color: .orange)
        }
    }

    // MARK: - Compact Layout (menu bar popover)

    private var compactProductivityCards: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                compactCard(title: "Pulse", value: String(format: "%.0f", activityVM.productivityPulse),
                            color: pulseColor(activityVM.productivityPulse))
                compactCard(title: "Productive", value: activityVM.productiveTimeString,
                            color: .green)
            }
            HStack(spacing: 6) {
                compactCard(title: "Neutral", value: activityVM.neutralTimeString,
                            color: .gray)
                compactCard(title: "Distracting", value: activityVM.distractingTimeString,
                            color: .red)
            }
        }
    }

    private var compactInputCards: some View {
        HStack(spacing: 6) {
            compactCard(title: "Active", value: activityVM.totalActiveTime, color: .calmTeal)
            compactCard(title: "Keys", value: formatNumber(activityVM.totalKeystrokes), color: .blue)
            compactCard(title: "Clicks", value: formatNumber(activityVM.totalClicks), color: .green)
            compactCard(title: "Avg/m", value: "\(activityVM.averageInputsPerActiveMinute)", color: .orange)
        }
    }

    // MARK: - Card Views

    private func compactCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(color)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(color.opacity(0.06))
        .cornerRadius(5)
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

    private func pulseColor(_ pulse: Double) -> Color {
        if pulse >= 75 { return .green }
        if pulse >= 50 { return .calmTeal }
        if pulse >= 25 { return .orange }
        return .red
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 10_000 {
            return String(format: "%.1fk", Double(n) / 1000)
        }
        return "\(n)"
    }
}
