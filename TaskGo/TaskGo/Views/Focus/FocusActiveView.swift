import SwiftUI

struct FocusActiveView: View {
    @EnvironmentObject var focusVM: FocusGuardViewModel
    @EnvironmentObject var taskVM: TaskViewModel
    @State private var editingContext = false

    private var service: FocusGuardService { focusVM.service }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "eye.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.calmTeal)
                Text("Focus Guard")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Circle()
                    .fill(service.lastVerdict == .onTask ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(service.lastVerdict == .onTask ? "On Task" : "Off Task")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(service.lastVerdict == .onTask ? .green : .red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("Working on")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.4))
                        Text(service.currentTask?.name ?? "")
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    HStack(spacing: 20) {
                        VStack(spacing: 2) {
                            Text(String(format: "%.0f%%", service.focusScore))
                                .font(.system(size: 28, weight: .bold).monospacedDigit())
                                .foregroundStyle(scoreColor)
                            Text("Focus Score")
                                .font(.system(size: 9))
                                .foregroundStyle(.primary.opacity(0.4))
                        }

                        VStack(spacing: 2) {
                            Text(focusVM.timeFormatted)
                                .font(.system(size: 28, weight: .bold).monospacedDigit())
                                .foregroundStyle(.primary.opacity(0.7))
                            Text("Elapsed")
                                .font(.system(size: 9))
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                    }

                    HStack(spacing: 16) {
                        stat(label: "Checks", value: "\(service.totalChecks)")
                        stat(label: "On Task", value: "\(service.onTaskChecks)")
                        stat(label: "Alerts", value: "\(service.offTaskNotifications)")
                    }

                    if !service.taskContext.isEmpty || editingContext {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Context")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.primary.opacity(0.4))
                                Spacer()
                                Button(action: {
                                    if editingContext {
                                        focusVM.updateContext()
                                    }
                                    editingContext.toggle()
                                }) {
                                    Text(editingContext ? "Save" : "Edit")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.calmTeal)
                                }
                                .buttonStyle(.plain)
                            }

                            if editingContext {
                                TextEditor(text: $focusVM.contextText)
                                    .font(.system(size: 10))
                                    .frame(height: 50)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2)))
                            } else {
                                Text(service.taskContext)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.primary.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
            }

            Divider()

            HStack(spacing: 8) {
                Button(action: {
                    if let task = focusVM.completeTask() {
                        Task { await taskVM.toggleComplete(task) }
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 9))
                        Text("Complete").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.calmTeal)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)

                Button(action: { focusVM.stopWithoutCompleting() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark.circle").font(.system(size: 9))
                        Text("Stop").font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)

                Button(action: { focusVM.snooze() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "moon.fill").font(.system(size: 8))
                        Text("Snooze 5m").font(.system(size: 10))
                    }
                    .foregroundStyle(.primary.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func stat(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(.primary.opacity(0.7))
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.primary.opacity(0.35))
        }
    }

    private var scoreColor: Color {
        if service.focusScore >= 80 { return .green }
        if service.focusScore >= 50 { return .orange }
        return .red
    }
}
