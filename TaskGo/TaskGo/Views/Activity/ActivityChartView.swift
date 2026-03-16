import SwiftUI
import Charts

struct ActivityChartView: View {
    @EnvironmentObject var activityVM: ActivityViewModel

    private var chartWidth: CGFloat {
        switch activityVM.snappedZoomLevel {
        case 1: return 4000
        case 5: return 2000
        case 15: return 1200
        case 30: return 800
        default: return 700
        }
    }

    private var barWidth: MarkDimension {
        switch activityVM.snappedZoomLevel {
        case 1: return .fixed(2)
        case 5: return .fixed(4)
        case 15: return .fixed(6)
        case 30: return .fixed(10)
        default: return .fixed(18)
        }
    }

    var body: some View {
        if activityVM.chartData.isEmpty || activityVM.chartData.allSatisfy({ $0.value == 0 }) {
            emptyState
        } else {
            ScrollView(.horizontal, showsIndicators: true) {
                chart
                    .frame(width: chartWidth, height: 200)
            }
        }
    }

    private var chart: some View {
        let bucketSize = Int(activityVM.snappedZoomLevel)

        return Chart(activityVM.chartData) { point in
            BarMark(
                x: .value("Time", point.bucketStart + bucketSize / 2),
                y: .value("Count", point.value),
                width: barWidth
            )
            .foregroundStyle(by: .value("Series", point.series.rawValue))
        }
        .chartForegroundStyleScale([
            "Keyboard": Color.blue,
            "Clicks": Color.green,
            "Scrolls": Color.orange,
            "Movement": Color.gray
        ])
        .chartXScale(domain: 0...1440)
        .chartXAxis {
            AxisMarks(values: .stride(by: 60.0)) { value in
                AxisValueLabel(anchor: .top) {
                    if let minute = value.as(Int.self) {
                        Text(formatHour(minute))
                            .font(.system(size: 11))
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let val = value.as(Int.self) {
                        Text("\(val)")
                            .font(.system(size: 10))
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.2, dash: [2, 2]))
            }
        }
        .chartLegend(.hidden)
    }

    private func formatHour(_ minute: Int) -> String {
        let h = minute / 60
        let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        let ampm = h >= 12 ? "PM" : "AM"
        return "\(h12) \(ampm)"
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
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}
