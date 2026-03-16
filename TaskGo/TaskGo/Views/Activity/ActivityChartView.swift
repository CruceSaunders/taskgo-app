import SwiftUI
import Charts

struct ActivityChartView: View {
    @EnvironmentObject var activityVM: ActivityViewModel

    private var minChartWidth: CGFloat {
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
            GeometryReader { outer in
                let availableWidth = outer.size.width - 44
                let useWidth = max(minChartWidth, availableWidth)

                HStack(alignment: .top, spacing: 0) {
                    yAxisLabels
                        .frame(width: 44)

                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(spacing: 0) {
                            chartBody
                                .frame(width: useWidth, height: 180)

                            hourLabelsRow
                                .frame(width: useWidth, height: 28)
                        }
                    }
                }
            }
            .frame(height: 212)
        }
    }

    private var yAxisLabels: some View {
        let maxVal = activityVM.chartData.map(\.value).max() ?? 100
        let step = yAxisStep(for: maxVal)
        let topTick = ((maxVal / step) + 1) * step
        let ticks = Array(stride(from: 0, through: topTick, by: step))

        let chartHeight: CGFloat = 180
        return ZStack {
            ForEach(ticks, id: \.self) { tick in
                let y = chartHeight - (chartHeight * CGFloat(tick) / CGFloat(topTick))
                Text("\(tick)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .position(x: 22, y: y)
            }
        }
        .frame(width: 44, height: chartHeight)
    }

    private func yAxisStep(for maxVal: Int) -> Int {
        if maxVal <= 10 { return 2 }
        if maxVal <= 50 { return 10 }
        if maxVal <= 200 { return 50 }
        if maxVal <= 500 { return 100 }
        if maxVal <= 2000 { return 500 }
        if maxVal <= 5000 { return 1000 }
        return 2000
    }

    private var chartBody: some View {
        let bucketSize = Int(activityVM.snappedZoomLevel)
        let maxVal = activityVM.chartData.map(\.value).max() ?? 100
        let step = yAxisStep(for: maxVal)
        let yMax = ((maxVal / step) + 1) * step

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
        .chartYScale(domain: 0...yMax)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    private var hourLabelsRow: some View {
        HStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(formatHour(hour))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let ampm = hour >= 12 ? "PM" : "AM"
        return "\(h12)\(ampm)"
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
