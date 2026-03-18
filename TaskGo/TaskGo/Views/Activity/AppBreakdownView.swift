import SwiftUI

struct AppBreakdownView: View {
    let apps: [AppDaySummary]
    var isCompact: Bool = false
    @State private var showAll = false

    private var defaultLimit: Int { isCompact ? 3 : 5 }

    private var displayedApps: [AppDaySummary] {
        if showAll { return apps }
        return Array(apps.prefix(defaultLimit))
    }

    private var totalSeconds: Int {
        apps.reduce(0) { $0 + $1.totalSeconds }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
            HStack {
                Text("Apps")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if apps.count > defaultLimit {
                    Button(action: { showAll.toggle() }) {
                        Text(showAll ? "Show less" : "Show all (\(apps.count))")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(Color.calmTeal)
                    }
                    .buttonStyle(.plain)
                }
            }

            if apps.isEmpty {
                HStack {
                    Spacer()
                    Text("No app data yet")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary.opacity(0.4))
                    Spacer()
                }
                .padding(.vertical, 6)
            } else {
                ForEach(displayedApps) { app in
                    appRow(app)
                }
            }
        }
    }

    private func appRow(_ app: AppDaySummary) -> some View {
        HStack(spacing: isCompact ? 6 : 8) {
            Circle()
                .fill(colorForScore(app.productivityScore))
                .frame(width: isCompact ? 6 : 8, height: isCompact ? 6 : 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.appName)
                    .font(.system(size: isCompact ? 9 : 10, weight: .medium))
                    .lineLimit(1)
                Text(app.category)
                    .font(.system(size: isCompact ? 7 : 8))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isCompact, totalSeconds > 0 {
                GeometryReader { geo in
                    let fraction = CGFloat(app.totalSeconds) / CGFloat(totalSeconds)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForScore(app.productivityScore).opacity(0.3))
                        .frame(width: max(2, fraction * geo.size.width))
                }
                .frame(width: 60, height: 6)
            }

            Text(formatSeconds(app.totalSeconds))
                .font(.system(size: isCompact ? 9 : 10, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: isCompact ? 35 : 45, alignment: .trailing)
        }
        .padding(.vertical, isCompact ? 2 : 3)
        .padding(.horizontal, isCompact ? 4 : 6)
        .background(Color.secondary.opacity(0.03))
        .cornerRadius(5)
    }

    private func formatSeconds(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}
