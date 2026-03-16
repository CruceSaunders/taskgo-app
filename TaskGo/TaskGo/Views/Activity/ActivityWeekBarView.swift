import SwiftUI

struct ActivityWeekBarView: View {
    @EnvironmentObject var activityVM: ActivityViewModel

    private var maxMinutes: Int {
        max(1, activityVM.weekSummary.map(\.activeMinutes).max() ?? 1)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(activityVM.weekSummary) { day in
                Button(action: {
                    activityVM.selectDay(day.date)
                }) {
                    VStack(spacing: 3) {
                        barColumn(day)
                            .frame(height: 30)
                        Text(day.dayLabel)
                            .font(.system(size: 8, weight: day.isSelected ? .bold : .regular))
                            .foregroundStyle(day.isSelected ? Color.calmTeal : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 48)
    }

    private func barColumn(_ day: WeekDaySummary) -> some View {
        let fraction = CGFloat(day.activeMinutes) / CGFloat(maxMinutes)
        let barH = max(2, 30 * fraction)

        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 2)
                .fill(day.isSelected ? Color.calmTeal : Color.calmTeal.opacity(0.35))
                .frame(height: barH)
        }
    }
}
