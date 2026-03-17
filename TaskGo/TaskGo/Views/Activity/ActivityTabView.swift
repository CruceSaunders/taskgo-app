import SwiftUI

struct ActivityTabView: View {
    @EnvironmentObject var activityVM: ActivityViewModel

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
            } else {
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
        }
        .onAppear {
            activityVM.loadSelectedDate()
        }
    }

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
}
