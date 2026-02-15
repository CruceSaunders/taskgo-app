import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var xpVM: XPViewModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Avatar / name
            VStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.calmTeal.opacity(0.6))

                if let profile = authVM.userProfile {
                    Text(profile.displayName)
                        .font(.system(size: 16, weight: .semibold))
                    Text("@\(profile.username)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            // Level and XP
            VStack(spacing: 8) {
                // Level badge
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.amber)
                    Text("Level \(xpVM.level)")
                        .font(.system(size: 18, weight: .bold))
                }

                // XP progress bar
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.calmTeal, Color.calmBlue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * xpVM.progressToNextLevel, height: 8)
                                .animation(.easeInOut(duration: 0.5), value: xpVM.progressToNextLevel)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("\(xpVM.totalXP) XP total")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if xpVM.level < 100 {
                            Text("\(xpVM.xpToNextLevel) XP to next level")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Max Level!")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.amber)
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Weekly XP
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 12))
                    Text("\(xpVM.weeklyXP) XP this week")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            }

            Spacer()

            // Sign out
            Button(action: {
                authVM.signOut()
            }) {
                Text("Sign Out")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
    }
}
