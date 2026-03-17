import SwiftUI

struct TrackingDiagnosticView: View {
    @ObservedObject private var watcher = WindowWatcher.shared
    @ObservedObject private var tracker = ActivityTracker.shared
    @State private var validationResults: [String] = []
    @State private var refreshID = UUID()

    private var refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Real-Time State")
                stateGrid

                sectionHeader("Active Segment")
                activeSegmentInfo

                sectionHeader("This Minute (Accumulators)")
                minuteAccumulators

                sectionHeader("Today Totals")
                todayTotals

                sectionHeader("Event Sources")
                eventSources

                sectionHeader("Last Harvest")
                Text(watcher.lastHarvestInfo.isEmpty ? "No harvest yet" : watcher.lastHarvestInfo)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)

                sectionHeader("Data Integrity Validation")
                validationSection

                HStack {
                    Button("Run Validation") { runValidation() }
                        .font(.system(size: 10))
                    Spacer()
                    Button("Refresh") { refreshID = UUID() }
                        .font(.system(size: 10))
                }
            }
            .padding(12)
            .id(refreshID)
        }
        .frame(width: 420, height: 520)
        .onReceive(refreshTimer) { _ in
            refreshID = UUID()
        }
        .onAppear { runValidation() }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.primary)
            .padding(.top, 4)
    }

    private var stateGrid: some View {
        VStack(alignment: .leading, spacing: 3) {
            diagRow("App", watcher.currentAppName)
            diagRow("Window", watcher.currentWindowTitle.isEmpty ? "(none)" : String(watcher.currentWindowTitle.prefix(60)))
            diagRow("Domain", watcher.currentDomain ?? "(none)")
            diagRow("Category", watcher.currentCategory)
            diagRow("Score", "\(watcher.currentProductivityLevel.rawValue) (\(watcher.currentProductivityLevel.label))")
            diagRow("Idle", watcher.isIdle ? "YES" : "no")
            diagRow("Task", watcher.activeTaskName ?? "(none)")
        }
    }

    private var activeSegmentInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            diagRow("Tracking", tracker.isTracking ? "ACTIVE" : "STOPPED")
            diagRow("Events Flowing", tracker.eventsAreFlowing ? "YES" : "no")
            diagRow("Permission", tracker.permissionState.rawValue)
        }
    }

    private var minuteAccumulators: some View {
        VStack(alignment: .leading, spacing: 3) {
            diagRow("Keyboard Events", "\(tracker.keyboardEventsReceived)")
            diagRow("Click Events", "\(tracker.clickEventsReceived)")
            diagRow("Scroll Events", "\(tracker.scrollEventsReceived)")
            diagRow("Move Events", "\(tracker.moveEventsReceived)")
        }
    }

    private var todayTotals: some View {
        let day = tracker.todayData
        return VStack(alignment: .leading, spacing: 3) {
            diagRow("Active Minutes", "\(day.totalActiveMinutes)")
            diagRow("Total Keyboard", "\(day.totalKeyboard)")
            diagRow("Total Clicks", "\(day.totalClicks)")
            diagRow("Minute Entries", "\(day.minuteData.count)")
            diagRow("Has App Data", day.hasAppTrackingData ? "YES" : "no")
            diagRow("Productivity Pulse", day.productivityPulse.map { String(format: "%.1f", $0) } ?? "n/a")
            diagRow("App Summary Count", "\(day.appSummary?.count ?? 0)")
            diagRow("WW Segments Today", "\(watcher.totalSegmentsToday)")
            diagRow("WW Seconds Today", "\(watcher.totalSegmentSecondsToday)")
        }
    }

    private var eventSources: some View {
        VStack(alignment: .leading, spacing: 3) {
            diagRow("Keyboard Healthy", tracker.keyboardHealthy ? "YES" : "NO")
            diagRow("KB Events Total", "\(tracker.keyboardEventsReceived)")
        }
    }

    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            if validationResults.isEmpty {
                Text("All checks passed")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.green)
            } else {
                ForEach(validationResults, id: \.self) { v in
                    Text(v)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
        }
    }

    private func diagRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .trailing)
            Text(value)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
        }
    }

    private func runValidation() {
        validationResults = tracker.todayData.validateIntegrity()
    }
}
