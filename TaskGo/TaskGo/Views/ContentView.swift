import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding || showOnboarding {
                OnboardingView(isComplete: Binding(
                    get: { hasCompletedOnboarding },
                    set: { newValue in
                        hasCompletedOnboarding = newValue
                        showOnboarding = false
                    }
                ))
            } else if authViewModel.isAuthenticated {
                MainView()
            } else {
                AuthView()
            }
        }
        .frame(width: 340, height: 400)
        .background(Color(.windowBackgroundColor))
    }
}
