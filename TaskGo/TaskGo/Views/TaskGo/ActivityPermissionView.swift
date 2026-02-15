import SwiftUI

struct ActivityPermissionView: View {
    @EnvironmentObject var taskGoVM: TaskGoViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.calmTeal)

            Text("Activity Verification")
                .font(.system(size: 16, weight: .bold))

            Text("TaskGo! can verify you're actually working during Task Go sessions to award XP fairly.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            VStack(alignment: .leading, spacing: 8) {
                PermissionBullet(
                    icon: "checkmark.shield",
                    text: "Only detects that you're active"
                )
                PermissionBullet(
                    icon: "eye.slash",
                    text: "Never logs what you type or click"
                )
                PermissionBullet(
                    icon: "star",
                    text: "Required to earn XP and compete"
                )
            }
            .padding(.horizontal, 8)

            VStack(spacing: 8) {
                Button(action: {
                    taskGoVM.requestActivityPermission()
                    isPresented = false
                }) {
                    Text("Enable in System Settings")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.calmTeal)
                .controlSize(.large)

                Button(action: {
                    isPresented = false
                }) {
                    Text("Skip — I don't need XP")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 280)
    }
}

struct PermissionBullet: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.calmTeal)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
        }
    }
}
