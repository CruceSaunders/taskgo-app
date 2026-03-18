import SwiftUI

struct ActivityTabView: View {
    @EnvironmentObject var activityVM: ActivityViewModel
    var isCompact: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if activityVM.showPermissionBanner {
                permissionBanner
            }

            dateHeader
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            Divider()

            if activityVM.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else if isCompact {
                compactContent
            } else {
                fullContent
            }
        }
        .onAppear {
            activityVM.loadSelectedDate()
        }
    }

    // MARK: - Compact Content (menu bar popover)

    private var compactContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                if activityVM.hasAppTrackingData {
                    compactPulseRow
                }

                compactInputRow

                if activityVM.hasAppTrackingData {
                    AppTimelineView(segments: activityVM.timelineSegments)

                    compactAppList
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
    }

    private var compactPulseRow: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                compactCard("Pulse", String(format: "%.0f", activityVM.productivityPulse),
                            pulseHeaderColor)
                compactCard("Productive", activityVM.productiveTimeString, .green)
                compactCard("Neutral", activityVM.neutralTimeString, .gray)
                compactCard("Distract.", activityVM.distractingTimeString, .red)
            }
        }
    }

    private var compactInputRow: some View {
        HStack(spacing: 6) {
            compactCard("Active", activityVM.totalActiveTime, .calmTeal)
            compactCard("Keys", formatNum(activityVM.totalKeystrokes), .blue)
            compactCard("Clicks", formatNum(activityVM.totalClicks), .green)
            compactCard("Avg/m", "\(activityVM.averageInputsPerActiveMinute)", .orange)
        }
    }

    private func compactCard(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(color)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(color.opacity(0.06))
        .cornerRadius(5)
    }

    private var compactAppList: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Apps")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            let apps = Array(activityVM.topApps.prefix(5))
            ForEach(apps) { app in
                HStack(spacing: 6) {
                    Circle()
                        .fill(colorForScore(app.productivityScore))
                        .frame(width: 6, height: 6)
                    Text(app.appName)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                    Text(app.category)
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(formatSec(app.totalSeconds))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Full Content (window view)

    private var fullContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                if activityVM.hasAppTrackingData {
                    productivityPulseHeader
                        .padding(.horizontal, 12)
                }

                ActivitySummaryView()
                    .padding(.horizontal, 12)

                if activityVM.hasAppTrackingData {
                    AppTimelineView(segments: activityVM.timelineSegments)
                        .padding(.horizontal, 12)

                    AppBreakdownView(apps: activityVM.topApps)
                        .padding(.horizontal, 12)
                }

                if !activityVM.weekSummary.isEmpty {
                    ActivityWeekBarView()
                        .padding(.horizontal, 12)
                }

                ActivityChartView()
                    .padding(.horizontal, 8)

                ActivityControlsView()
                    .padding(.horizontal, 12)

                Divider()
                    .padding(.horizontal, 12)

                detailSection
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Shared Components

    private var permissionBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("Accessibility permission required")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.primary)
                Text("Grant access, then restart the app")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer()
            Button("Grant") {
                ActivityTracker.shared.requestPermission()
            }
            .font(.system(size: 9, weight: .semibold))
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.mini)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.08))
    }

    private var dateHeader: some View {
        HStack {
            Button(action: { activityVM.goToPreviousDay() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 1) {
                Text(activityVM.displayDateString)
                    .font(.system(size: 12, weight: .semibold))
                if let first = activityVM.firstActivityTime, let last = activityVM.lastActivityTime {
                    Text("\(first) - \(last)")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if activityVM.isToday {
                HStack(spacing: 2) {
                    Circle()
                        .fill(activityVM.eventsFlowing ? Color.green : Color.orange)
                        .frame(width: 5, height: 5)
                    Text(activityVM.eventsFlowing ? "Live" : "Off")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(activityVM.eventsFlowing ? .green : .orange)
                }
            } else {
                Button(action: { activityVM.goToNextDay() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var productivityPulseHeader: some View {
        VStack(spacing: 2) {
            Text(String(format: "%.0f", activityVM.productivityPulse))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(pulseHeaderColor)
            Text("Productivity Pulse")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private var pulseHeaderColor: Color {
        let pulse = activityVM.productivityPulse
        if pulse >= 75 { return .green }
        if pulse >= 50 { return .calmTeal }
        if pulse >= 25 { return .orange }
        return .red
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Details")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)

            if let day = activityVM.currentDay {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 3) {
                    detailCell("Inputs", "\(day.meaningfulInputs)")
                    detailCell("Active", "\(day.totalActiveMinutes)m")
                    detailCell("Engaged", activityVM.engagedTime)
                    detailCell("Scrolls", "\(day.totalScrolls)")
                    detailCell("Moves", "\(day.totalMovement)")
                    detailCell("Avg/min", "\(activityVM.averageInputsPerActiveMinute)")
                }
            } else {
                Text("No data")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
        }
    }

    private func detailCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(.system(size: 7))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(4)
    }

    private func formatNum(_ n: Int) -> String {
        if n >= 10_000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }

    private func formatSec(_ seconds: Int) -> String {
        let m = seconds / 60
        if m >= 60 { return "\(m / 60)h \(m % 60)m" }
        return "\(m)m"
    }
}
