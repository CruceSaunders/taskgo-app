import SwiftUI

struct ActivityControlsView: View {
    @EnvironmentObject var activityVM: ActivityViewModel

    var body: some View {
        VStack(spacing: 8) {
            // Series toggles (legend + filter)
            HStack(spacing: 6) {
                ForEach(DataSeries.allCases) { series in
                    seriesToggle(series)
                }
                Spacer()
            }

            // Zoom level buttons
            HStack(spacing: 6) {
                ForEach(ActivityViewModel.zoomSteps, id: \.self) { step in
                    zoomButton(step)
                }
                Spacer()
            }
        }
    }

    private func zoomButton(_ step: Double) -> some View {
        let isSelected = activityVM.snappedZoomLevel == step
        let label = step >= 60 ? "1 hour" : "\(Int(step)) min"
        return Button(action: {
            activityVM.zoomLevel = step
        }) {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isSelected ? Color.calmTeal : Color.secondary.opacity(0.08))
                .foregroundStyle(isSelected ? .white : Color.secondary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func seriesToggle(_ series: DataSeries) -> some View {
        let isOn = activityVM.visibleSeries.contains(series)
        let color = colorForSeries(series)
        return Button(action: {
            if isOn {
                if activityVM.visibleSeries.count > 1 {
                    activityVM.visibleSeries.remove(series)
                }
            } else {
                activityVM.visibleSeries.insert(series)
            }
        }) {
            HStack(spacing: 4) {
                Circle()
                    .fill(isOn ? color : color.opacity(0.3))
                    .frame(width: 7, height: 7)
                Text(series.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isOn ? color.opacity(0.12) : Color.secondary.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isOn ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(6)
            .foregroundStyle(isOn ? Color.primary : Color.secondary.opacity(0.5))
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
