import SwiftUI

struct CreatePlanView: View {
    @EnvironmentObject var plannerVM: PlannerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()

    private var dayCount: Int {
        max(0, (Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && endDate >= startDate && dayCount <= 90
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            formContent
            Divider()
            footer
        }
        .frame(width: 320)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            let suggestion = Plan.suggestedTitle(start: startDate, end: endDate)
            if !suggestion.isEmpty { title = suggestion }
        }
    }

    private var header: some View {
        HStack {
            Text("New Plan")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.5))
                TextField("Weekly Sprint, Exam Prep...", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.5))
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .font(.system(size: 11))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("End")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.5))
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .font(.system(size: 11))
                }
            }

            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.calmTeal)
                Text("\(dayCount) day\(dayCount == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.7))

                if dayCount > 90 {
                    Spacer()
                    Text("Max 90 days")
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
            .padding(.vertical, 2)
        }
        .padding(16)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)

            Button(action: create) {
                Text("Create Plan")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(isValid ? Color.calmTeal : Color.gray.opacity(0.4))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!isValid)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func create() {
        guard isValid else { return }
        plannerVM.createPlan(
            title: title.trimmingCharacters(in: .whitespaces),
            startDate: startDate,
            endDate: endDate
        )
        dismiss()
    }
}
