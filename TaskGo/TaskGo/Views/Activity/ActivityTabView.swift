import SwiftUI

struct ActivityTabView: View {
    @EnvironmentObject var activityVM: ActivityViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if !ActivityTracker.shared.hasPermission {
                permissionBanner
            }

            // Date navigation
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
                ScrollView {
                    VStack(spacing: 12) {
                        // Summary cards
                        ActivitySummaryView()
                            .padding(.horizontal, 12)

                        // Chart
                        ActivityChartView()
                            .frame(minHeight: 180, maxHeight: 260)
                            .padding(.horizontal, 8)

                        Divider()
                            .padding(.horizontal, 12)

                        // Controls
                        ActivityControlsView()

                        Divider()
                            .padding(.horizontal, 12)

                        // Detail stats
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
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
            Text("Activity tracking requires Input Monitoring permission.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Enable") {
                ActivityTracker.shared.requestPermission()
            }
            .font(.system(size: 10, weight: .medium))
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
                Text("Live")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .clipShape(Capsule())
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if let day = activityVM.currentDay {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 6) {
                    detailRow("Total Inputs", value: "\(day.totalInputs)")
                    detailRow("Active Minutes", value: "\(day.totalActiveMinutes)")
                    detailRow("Engaged Minutes", value: "\(day.totalEngagedMinutes)")
                    detailRow("Present Minutes", value: "\(day.totalPresentMinutes)")
                    detailRow("Scrolls", value: "\(day.totalScrolls)")
                    detailRow("Mouse Moves", value: "\(day.totalMovement)")
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
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(4)
    }
}
