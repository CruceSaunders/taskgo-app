import SwiftUI

struct PlannerTabView: View {
    @EnvironmentObject var plannerVM: PlannerViewModel

    var body: some View {
        HStack(spacing: 0) {
            plannerSidebar
                .frame(width: 120)

            Divider()

            if plannerVM.showCreatePlan {
                CreatePlanView()
            } else {
                PlanDetailView()
            }
        }
        .onAppear {
            plannerVM.startListening()
        }
        .onDisappear {
            plannerVM.flushSave()
        }
    }

    // MARK: - Sidebar

    private var plannerSidebar: some View {
        VStack(spacing: 0) {
            Button(action: { plannerVM.showCreatePlan = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                    Text("New Plan")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color.calmTeal)
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 4)

            filterBar
                .padding(.horizontal, 6)
                .padding(.bottom, 4)

            Divider()

            if plannerVM.filteredPlans.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "tray")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary.opacity(0.15))
                    Text(plannerVM.filter == .completed ? "No completed plans" : "No plans yet")
                        .font(.system(size: 9))
                        .foregroundStyle(.primary.opacity(0.3))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(plannerVM.filteredPlans) { plan in
                            planCard(plan)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            }
        }
        .background(Color.secondary.opacity(0.04))
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 0) {
            ForEach(PlanFilter.allCases, id: \.self) { f in
                Button(action: { plannerVM.filter = f }) {
                    Text(f.rawValue)
                        .font(.system(size: 9, weight: plannerVM.filter == f ? .semibold : .regular))
                        .foregroundStyle(plannerVM.filter == f ? Color.calmTeal : .primary.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .background(plannerVM.filter == f ? Color.calmTeal.opacity(0.12) : Color.clear)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(4)
    }

    // MARK: - Plan Card

    private func planCard(_ plan: Plan) -> some View {
        Button(action: { plannerVM.selectPlan(plan) }) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if plan.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                    }
                    Text(plan.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(plannerVM.selectedPlan?.id == plan.id ? .white : .primary.opacity(0.85))
                        .lineLimit(1)
                }

                Text(plan.displayDateRange)
                    .font(.system(size: 8))
                    .foregroundStyle(plannerVM.selectedPlan?.id == plan.id ? .white.opacity(0.7) : .primary.opacity(0.4))

                if plan.totalObjectives > 0 {
                    HStack(spacing: 4) {
                        progressMini(plan)
                        Text("\(plan.completedObjectives)/\(plan.totalObjectives)")
                            .font(.system(size: 8).monospacedDigit())
                            .foregroundStyle(plannerVM.selectedPlan?.id == plan.id ? .white.opacity(0.6) : .primary.opacity(0.35))
                    }
                } else {
                    Text("\(plan.dayCount) day\(plan.dayCount == 1 ? "" : "s")")
                        .font(.system(size: 8))
                        .foregroundStyle(plannerVM.selectedPlan?.id == plan.id ? .white.opacity(0.6) : .primary.opacity(0.35))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(plannerVM.selectedPlan?.id == plan.id ? Color.calmTeal : Color.clear)
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(plan.isComplete ? "Reopen Plan" : "Complete Plan") {
                plannerVM.selectPlan(plan)
                if plan.isComplete {
                    plannerVM.reopenPlan()
                } else {
                    plannerVM.completePlan()
                }
            }
            Divider()
            Button("Delete Plan", role: .destructive) {
                plannerVM.deletePlan(plan)
            }
        }
    }

    private func progressMini(_ plan: Plan) -> some View {
        let isSelected = plannerVM.selectedPlan?.id == plan.id
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.12))
                    .frame(height: 3)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? Color.white.opacity(0.8) : Color.calmTeal)
                    .frame(width: max(0, geo.size.width * plan.progress), height: 3)
            }
        }
        .frame(height: 3)
    }
}
