import SwiftUI
import Charts

struct ActivityChartView: View {
    @EnvironmentObject var activityVM: ActivityViewModel

    private var needsScroll: Bool {
        activityVM.snappedZoomLevel < 60
    }

    private var chartWidth: CGFloat {
        switch activityVM.snappedZoomLevel {
        case 1: return 4000
        case 5: return 2000
        case 15: return 1200
        case 30: return 800
        default: return 0
        }
    }

    private var barWidth: MarkDimension {
        switch activityVM.snappedZoomLevel {
        case 1: return .fixed(1.5)
        case 5: return .fixed(2)
        case 15: return .fixed(3)
        case 30: return .fixed(5)
        default: return .fixed(8)
        }
    }

    var body: some View {
        if activityVM.chartData.isEmpty || activityVM.chartData.allSatisfy({ $0.value == 0 }) {
            emptyState
        } else if needsScroll {
            ScrollView(.horizontal, showsIndicators: true) {
                chart
                    .frame(width: chartWidth, height: 180)
            }
        } else {
            chart
                .frame(height: 180)
        }
    }

    private var chart: some View {
        Chart(activityVM.chartData) { point in
            BarMark(
                x: .value("Time", point.bucketStart),
                y: .value("Count", point.value),
                width: barWidth
            )
            .foregroundStyle(by: .value("Series", point.series.rawValue))
            .position(by: .value("Series", point.series.rawValue))
        }
        .chartForegroundStyleScale([
            "Keyboard": Color.blue,
            "Clicks": Color.green,
            "Scrolls": Color.orange,
            "Movement": Color.gray
        ])
        .chartXScale(domain: 0...1440)
        .chartXAxis {
            AxisMarks(values: .stride(by: Double(xAxisInterval))) { value in
                AxisValueLabel {
                    if let minute = value.as(Int.self) {
                        Text(formatMinute(minute))
                            .font(.system(size: 7))
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.2))
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
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.2, dash: [2, 2]))
            }
        }
        .chartLegend(.hidden)
        .padding(.leading, 4)
    }

    private var xAxisInterval: Int {
        switch activityVM.snappedZoomLevel {
        case 1: return 30
        case 5: return 60
        case 15: return 60
        case 30: return 60
        default: return 60
        }
    }

    private func formatMinute(_ minute: Int) -> String {
        let h = minute / 60
        let m = minute % 60
        let ampm = h >= 12 ? "p" : "a"
        let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        if m == 0 { return "\(h12)\(ampm)" }
        return String(format: "%d:%02d", h12, m)
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
