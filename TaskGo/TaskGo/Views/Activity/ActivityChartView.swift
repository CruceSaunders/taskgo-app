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

    private var hasData: Bool {
        if activityVM.viewMode == .productivity {
            return !activityVM.productivityChartData.isEmpty &&
                   activityVM.productivityChartData.contains { $0.activeMinutes > 0 }
        }
        return !activityVM.chartData.isEmpty &&
               activityVM.chartData.contains { $0.value > 0 }
    }

    private var bucketSize: Int { Int(activityVM.snappedZoomLevel) }

    private var computedYMax: Int {
        if activityVM.viewMode == .productivity {
            let maxVal = activityVM.productivityChartData.map(\.activeMinutes).max() ?? bucketSize
            let step = yAxisStep(for: maxVal)
            return max(((maxVal / step) + 1) * step, bucketSize)
        }
        let maxVal = activityVM.chartData.map(\.value).max() ?? 100
        let step = yAxisStep(for: maxVal)
        return ((maxVal / step) + 1) * step
    }

    private var bucketLabel: String {
        let s = bucketSize
        if s >= 60 { return "per hour" }
        return "per \(s) min"
    }

    var body: some View {
        if !hasData {
            emptyState
        } else {
            VStack(spacing: 2) {
                GeometryReader { outer in
                    let availableWidth = outer.size.width - 44
                    let useWidth = max(minChartWidth, availableWidth)
                    let yMax = computedYMax

                    HStack(alignment: .top, spacing: 0) {
                        yAxisLabels(yMax: yMax)
                            .frame(width: 44)

                        ScrollView(.horizontal, showsIndicators: false) {
                            VStack(spacing: 0) {
                                if activityVM.viewMode == .activity {
                                    activityChartBody(yMax: yMax)
                                        .frame(width: useWidth, height: 180)
                                } else {
                                    productivityChartBody(yMax: yMax)
                                        .frame(width: useWidth, height: 180)
                                }

                                hourLabelsRow
                                    .frame(width: useWidth, height: 28)
                            }
                        }
                    }
                }
                .frame(height: 212)

                Text(bucketLabel)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
        }
    }

    // MARK: - Y Axis (uses shared yMax)

    private func yAxisLabels(yMax: Int) -> some View {
        let step = yAxisStep(for: yMax > 0 ? yMax : 1)
        let ticks = Array(stride(from: 0, through: yMax, by: step))

        let chartHeight: CGFloat = 180
        return ZStack {
            ForEach(ticks, id: \.self) { tick in
                let y = chartHeight - (chartHeight * CGFloat(tick) / CGFloat(max(yMax, 1)))
                Text("\(tick)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .position(x: 22, y: y)
            }
        }
        .frame(width: 44, height: chartHeight)
    }

    private func yAxisStep(for maxVal: Int) -> Int {
        if maxVal <= 5 { return 1 }
        if maxVal <= 10 { return 2 }
        if maxVal <= 30 { return 5 }
        if maxVal <= 60 { return 10 }
        if maxVal <= 200 { return 50 }
        if maxVal <= 500 { return 100 }
        if maxVal <= 2000 { return 500 }
        if maxVal <= 5000 { return 1000 }
        return 2000
    }

    // MARK: - Activity Chart (uses shared yMax)

    private func activityChartBody(yMax: Int) -> some View {
        Chart(activityVM.chartData) { point in
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
            "Movement": Color.gray,
            "Speaking": Color.purple,
            "Watching": Color.pink
        ])
        .chartXScale(domain: 0...1440)
        .chartYScale(domain: 0...yMax)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    // MARK: - Productivity Chart (uses shared yMax)

    private func productivityChartBody(yMax: Int) -> some View {
        Chart(activityVM.productivityChartData) { point in
            BarMark(
                x: .value("Time", point.bucketStart + bucketSize / 2),
                y: .value("Minutes", point.activeMinutes),
                width: barWidth
            )
            .foregroundStyle(Color.calmTeal)
        }
        .chartXScale(domain: 0...1440)
        .chartYScale(domain: 0...yMax)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    // MARK: - Hour Labels

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
