import SwiftUI

struct ActivityControlsView: View {
    @EnvironmentObject var activityVM: ActivityViewModel

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(DataSeries.allCases) { series in
                    seriesToggle(series)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)

                Slider(
                    value: $activityVM.zoomLevel,
                    in: 1...60,
                    step: 1
                )
                .onChange(of: activityVM.zoomLevel) { _, newValue in
                    let snapped = ActivityViewModel.zoomSteps.min(by: {
                        abs($0 - newValue) < abs($1 - newValue)
                    }) ?? 60
                    if activityVM.zoomLevel != snapped {
                        activityVM.zoomLevel = snapped
                    }
                }

                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)

                Text(activityVM.zoomLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }

    private func seriesToggle(_ series: DataSeries) -> some View {
        let isOn = activityVM.visibleSeries.contains(series)
        return Button(action: {
            if isOn {
                if activityVM.visibleSeries.count > 1 {
                    activityVM.visibleSeries.remove(series)
                }
            } else {
                activityVM.visibleSeries.insert(series)
            }
        }) {
            HStack(spacing: 3) {
                Circle()
                    .fill(colorForSeries(series))
                    .frame(width: 5, height: 5)
                Text(series.rawValue)
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isOn ? colorForSeries(series).opacity(0.12) : Color.secondary.opacity(0.04))
            .cornerRadius(4)
            .foregroundStyle(isOn ? Color.primary : Color.secondary.opacity(0.4))
        }
        .buttonStyle(.plain)
    }

    private func colorForSeries(_ series: DataSeries) -> Color {
        switch series {
        case .keyboard: return .blue
        case .clicks: return .green
        case .scrolls: return .orange
        case .movement: return .gray
        }
    }
}
