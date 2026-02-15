import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var updater = SparkleUpdater()
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Failed to update launch at login: \(error)")
                        }
                    }
            }

            Section("Account") {
                if let profile = authVM.userProfile {
                    LabeledContent("Username", value: "@\(profile.username)")
                    LabeledContent("Email", value: profile.email)
                }
            }

            Section("Updates") {
                Button("Check for Updates...") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.appVersion)
                LabeledContent("Build", value: Bundle.main.buildNumber)
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 300)
    }
}

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
