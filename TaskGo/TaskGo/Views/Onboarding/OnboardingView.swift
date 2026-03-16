import SwiftUI
import ServiceManagement

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var currentPage = 0
    @State private var launchAtLogin = true
    @State private var hasInputMonitoring = false

    private let totalPages = 5

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
        ),
        OnboardingPage(
            icon: "chart.bar.xaxis",
            iconColor: .blue,
            title: "Activity Tracking",
            subtitle: "Understand your productivity patterns",
            description: "TaskGo! tracks your keyboard and mouse activity to show you when you're most productive. We never log what you type — only that activity occurred."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            if currentPage < pages.count {
                pageView(pages[currentPage])
                    .frame(height: 340)
                    .animation(.easeInOut(duration: 0.25), value: currentPage)
            } else {
                setupPage
                    .frame(height: 340)
                    .animation(.easeInOut(duration: 0.25), value: currentPage)
            }

            HStack(spacing: 6) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.calmTeal : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            .padding(.bottom, 16)

            HStack(spacing: 12) {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation { currentPage -= 1 }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Spacer()

                if currentPage < totalPages - 1 {
                    Button("Next") {
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.calmTeal)
                    .controlSize(.large)
                } else {
                    Button("Get Started") {
                        applySetupSettings()
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
        .onAppear {
            ActivityTracker.shared.checkPermission()
            hasInputMonitoring = ActivityTracker.shared.hasPermission
        }
    }

    // MARK: - Standard Page

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
                .foregroundStyle(.primary.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Setup Page

    private var setupPage: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "gearshape.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.calmTeal)

            Text("Quick Setup")
                .font(.system(size: 20, weight: .bold))
                .multilineTextAlignment(.center)

            Text("Get the most out of TaskGo!")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.calmTeal)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                // Launch at login
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Always running so activity is tracked")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .padding(.horizontal, 20)

                Divider()
                    .padding(.horizontal, 20)

                // Input Monitoring permission
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Activity Tracking")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Requires Input Monitoring permission")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if hasInputMonitoring {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                            Text("Enabled")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.green)
                        }
                    } else {
                        Button("Enable") {
                            ActivityTracker.shared.requestPermission()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                ActivityTracker.shared.checkPermission()
                                hasInputMonitoring = ActivityTracker.shared.hasPermission
                            }
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.borderedProminent)
                        .tint(Color.calmTeal)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Apply Settings

    private func applySetupSettings() {
        UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[Onboarding] Failed to set launch at login: \(error)")
        }
    }
}

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
}
