import SwiftUI

struct ActivityControlsView: View {
    @EnvironmentObject var activityVM: ActivityViewModel

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(DataSeries.allCases) { series in
                    seriesToggle(series)
                }
                Spacer()
            }

            HStack(spacing: 4) {
                ForEach(ActivityViewModel.zoomSteps, id: \.self) { step in
                    zoomButton(step)
                }
                Spacer()
            }
        }
    }

    private func zoomButton(_ step: Double) -> some View {
        let isSelected = activityVM.snappedZoomLevel == step
        let label = step >= 60 ? "1h" : "\(Int(step))m"
        return Button(action: {
            activityVM.zoomLevel = step
        }) {
            Text(label)
                .font(.system(size: 8, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isSelected ? Color.calmTeal.opacity(0.15) : Color.secondary.opacity(0.04))
                .foregroundStyle(isSelected ? Color.calmTeal : Color.secondary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
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
            HStack(spacing: 2) {
                Circle()
                    .fill(colorForSeries(series))
                    .frame(width: 5, height: 5)
                Text(series.rawValue)
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 5)
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
