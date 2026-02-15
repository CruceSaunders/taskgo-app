import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainView()
            } else {
                AuthView()
            }
        }
        .frame(width: 360, height: 480)
    }
}
