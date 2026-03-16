import SwiftUI

struct ActivityWeekBarView: View {
    @EnvironmentObject var activityVM: ActivityViewModel

    private var maxMinutes: Int {
        max(1, activityVM.weekSummary.map(\.activeMinutes).max() ?? 1)
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(activityVM.weekSummary) { day in
                Button(action: {
                    activityVM.selectDay(day.date)
                }) {
                    VStack(spacing: 2) {
                        barFill(day)
                        Text(day.dayLabel)
                            .font(.system(size: 8, weight: day.isSelected ? .bold : .regular))
                            .foregroundStyle(day.isSelected ? Color.calmTeal : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 50)
    }

    private func barFill(_ day: WeekDaySummary) -> some View {
        GeometryReader { geo in
            let fraction = CGFloat(day.activeMinutes) / CGFloat(maxMinutes)
            let barHeight = max(2, geo.size.height * fraction)

            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(day.isSelected ? Color.calmTeal : Color.calmTeal.opacity(0.4))
                    .frame(height: barHeight)
            }
        }
    }
}
