import SwiftUI

struct ActivityTabView: View {
    @EnvironmentObject var activityVM: ActivityViewModel

    var body: some View {
        VStack(spacing: 0) {
            if !activityVM.permissionGranted {
                permissionBanner
            }

            dateHeader
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            if activityVM.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        ActivitySummaryView()
                            .padding(.horizontal, 12)

                        ActivityChartView()
                            .frame(height: 200)
                            .padding(.horizontal, 12)

                        ActivityControlsView()
                            .padding(.horizontal, 12)

                        Divider()
                            .padding(.horizontal, 12)

                        detailSection
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .onAppear {
            activityVM.loadSelectedDate()
        }
    }

    // MARK: - Permission Banner

    private var permissionBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            Text("Input Monitoring permission required")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button("Enable") {
                ActivityTracker.shared.requestPermission()
            }
            .font(.system(size: 9, weight: .semibold))
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.mini)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.orange.opacity(0.08))
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack {
            Button(action: { activityVM.goToPreviousDay() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 1) {
                Text(activityVM.displayDateString)
                    .font(.system(size: 13, weight: .semibold))
                if let first = activityVM.firstActivityTime, let last = activityVM.lastActivityTime {
                    Text("\(first) - \(last)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if activityVM.isToday {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                    Text("Live")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.green)
                }
            } else {
                Button(action: { activityVM.goToNextDay() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Detail Section

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Details")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            if let day = activityVM.currentDay {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 4) {
                    detailRow("Total Inputs", value: "\(day.totalInputs)")
                    detailRow("Active Minutes", value: "\(day.totalActiveMinutes)")
                    detailRow("Engaged Minutes", value: "\(day.totalEngagedMinutes)")
                    detailRow("Scrolls", value: "\(day.totalScrolls)")
                    detailRow("Mouse Moves", value: "\(day.totalMovement)")
                    detailRow("Avg/min", value: "\(activityVM.averageInputsPerActiveMinute)")
                }
            } else {
                Text("No data available")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 9, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(3)
    }
}
