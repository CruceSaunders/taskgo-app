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
                LineMark(
                    x: .value("Minute", point.bucketStart),
                    y: .value("Count", point.value)
                )
                .foregroundStyle(by: .value("Series", point.series.rawValue))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5))

                AreaMark(
                    x: .value("Minute", point.bucketStart),
                    y: .value("Count", point.value)
                )
                .foregroundStyle(by: .value("Series", point.series.rawValue))
                .opacity(0.1)
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
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.system(size: 8))
                                .rotationEffect(.degrees(-45))
                        }
                    }
                    AxisGridLine()
                }
            } else {
                AxisMarks(values: .automatic(desiredCount: 12)) { value in
                    AxisValueLabel {
                        if let minute = value.as(Int.self) {
                            Text(formatMinuteOfDay(minute))
                                .font(.system(size: 8))
                                .rotationEffect(.degrees(-45))
                        }
                    }
                    AxisGridLine()
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let val = value.as(Int.self) {
                        Text("\(val)")
                            .font(.system(size: 8))
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            }
        }
        .chartLegend(.visible)
        .padding(.horizontal, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("No activity data")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(activityVM.isToday ? "Activity will appear here as you work" : "No data recorded for this day")
                .font(.system(size: 10))
                .foregroundStyle(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatMinuteOfDay(_ minute: Int) -> String {
        let h = minute / 60
        let m = minute % 60
        let ampm = h >= 12 ? "PM" : "AM"
        let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return String(format: "%d:%02d %@", h12, m, ampm)
    }
}
