import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "checkmark.circle.fill",
            iconColor: .calmTeal,
            title: "Welcome to TaskGo!",
            subtitle: "The productivity app that keeps you on track",
            description: "TaskGo! lives in your menu bar, ready whenever you need it. Add tasks, set time estimates, and let Task Go mode keep you focused."
        ),
        OnboardingPage(
            icon: "bolt.fill",
            iconColor: .amber,
            title: "Task Go Mode",
            subtitle: "Your personal focus engine",
            description: "Press \"Task Go!\" and a floating timer appears on screen. It counts down your task time, then bounces to let you know when time's up. Stay in the zone."
        ),
        OnboardingPage(
            icon: "star.fill",
            iconColor: .orange,
            title: "Earn XP & Level Up",
            subtitle: "Gamify your productivity",
            description: "Earn 1 XP for every minute you work during Task Go. Level up to 100 and track your progress over time."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.automatic)
            .frame(height: 340)

            // Page indicators
            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.calmTeal : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            .padding(.bottom, 16)

            // Buttons
            HStack(spacing: 12) {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation { currentPage -= 1 }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.calmTeal)
                    .controlSize(.large)
                } else {
                    Button("Get Started") {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        isComplete = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.calmTeal)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 48))
                .foregroundStyle(page.iconColor)

            Text(page.title)
                .font(.system(size: 20, weight: .bold))
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.calmTeal)
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
}
