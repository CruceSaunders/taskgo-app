import SwiftUI
import Charts

struct ActivityChartView: View {
    @EnvironmentObject var activityVM: ActivityViewModel

    var body: some View {
        if activityVM.chartData.isEmpty {
            emptyState
        } else {
            chartContent
        }
    }

    private var chartContent: some View {
        Chart(activityVM.chartData) { point in
            if activityVM.snappedZoomLevel >= 30 {
                BarMark(
                    x: .value("Time", point.label),
                    y: .value("Count", point.value)
                )
                .foregroundStyle(by: .value("Series", point.series.rawValue))
                .position(by: .value("Series", point.series.rawValue))
            } else {
                AreaMark(
                    x: .value("Minute", point.bucketStart),
                    y: .value("Count", point.value)
                )
                .foregroundStyle(by: .value("Series", point.series.rawValue))
                .opacity(0.15)

                LineMark(
                    x: .value("Minute", point.bucketStart),
                    y: .value("Count", point.value)
                )
                .foregroundStyle(by: .value("Series", point.series.rawValue))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .chartForegroundStyleScale([
            "Keyboard": Color.blue,
            "Clicks": Color.green,
            "Scrolls": Color.orange,
            "Movement": Color.gray
        ])
        .chartXAxis {
            if activityVM.snappedZoomLevel >= 30 {
                AxisMarks(values: .automatic(desiredCount: 8)) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.system(size: 7))
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                }
            } else {
                AxisMarks(values: .automatic(desiredCount: 8)) { value in
                    AxisValueLabel {
                        if let minute = value.as(Int.self) {
                            Text(formatMinuteOfDay(minute))
                                .font(.system(size: 7))
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let val = value.as(Int.self) {
                        Text("\(val)")
                            .font(.system(size: 7))
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [3, 3]))
            }
        }
        .chartLegend(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 24))
                .foregroundStyle(.secondary.opacity(0.3))
            Text("No activity data")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(activityVM.isToday ? "Activity will appear as you work" : "No data for this day")
                .font(.system(size: 9))
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatMinuteOfDay(_ minute: Int) -> String {
        let h = minute / 60
        let m = minute % 60
        let ampm = h >= 12 ? "p" : "a"
        let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        if m == 0 {
            return "\(h12)\(ampm)"
        }
        return String(format: "%d:%02d", h12, m)
    }
}
