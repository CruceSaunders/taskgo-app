import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var updater = SparkleUpdater()
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    @State private var selectedProvider: LLMProvider = .selectedProvider
    @State private var apiKeyInput = ""
    @State private var modelOverride = ""
    @State private var hasKey = false
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var showingCategoryRules = false
    @State private var showingDiagnostics = false

    @State private var trackWindowTitles: Bool = true
    @State private var trackBrowserURLs: Bool = true
    @State private var storeFullURLs: Bool = false

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

            Section("Activity Tracking") {
                Toggle("Track window titles", isOn: $trackWindowTitles)
                    .onChange(of: trackWindowTitles) { _, newValue in
                        var prefs = TrackingPreferences.load()
                        prefs.trackWindowTitles = newValue
                        prefs.save()
                    }

                Toggle("Track browser URLs", isOn: $trackBrowserURLs)
                    .onChange(of: trackBrowserURLs) { _, newValue in
                        var prefs = TrackingPreferences.load()
                        prefs.trackBrowserURLs = newValue
                        prefs.save()
                    }

                if trackBrowserURLs {
                    Toggle("Store full URLs (not just domains)", isOn: $storeFullURLs)
                        .onChange(of: storeFullURLs) { _, newValue in
                            var prefs = TrackingPreferences.load()
                            prefs.storeFullURLs = newValue
                            prefs.save()
                        }
                }

                Button("Manage Category Rules...") {
                    showingCategoryRules = true
                }
                .font(.system(size: 11))

                Button("Diagnostics...") {
                    showingDiagnostics = true
                }
                .font(.system(size: 11))
            }

            Section("AI Provider") {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .onChange(of: selectedProvider) { _, newValue in
                    LLMProvider.selectedProvider = newValue
                    hasKey = KeychainService.hasAPIKey(for: newValue.rawValue)
                    apiKeyInput = ""
                    modelOverride = LLMProvider.selectedModel ?? ""
                    testResult = nil
                }

                if hasKey {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 12))
                        Text("API key saved")
                            .font(.system(size: 11))
                            .foregroundStyle(.primary.opacity(0.6))
                        Spacer()
                        Button("Remove") {
                            KeychainService.deleteAPIKey(for: selectedProvider.rawValue)
                            hasKey = false
                            testResult = nil
                        }
                        .foregroundStyle(.red)
                        .font(.system(size: 11))
                    }
                } else {
                    HStack {
                        SecureField(selectedProvider.keyPlaceholder, text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                        Button("Save") {
                            let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !key.isEmpty else { return }
                            KeychainService.saveAPIKey(key, for: selectedProvider.rawValue)
                            hasKey = true
                            apiKeyInput = ""
                            testResult = nil
                        }
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                TextField("Model (default: \(selectedProvider.defaultModel))", text: $modelOverride)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .onChange(of: modelOverride) { _, newValue in
                        LLMProvider.selectedModel = newValue.isEmpty ? nil : newValue
                    }

                HStack {
                    Button(action: testKey) {
                        HStack(spacing: 4) {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            }
                            Text(isTesting ? "Testing..." : "Test Key")
                        }
                    }
                    .disabled(!hasKey || isTesting)

                    if let result = testResult {
                        Text(result)
                            .font(.system(size: 10))
                            .foregroundStyle(result.contains("Success") ? .green : .red)
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
        .frame(width: 400, height: 560)
        .onAppear {
            selectedProvider = LLMProvider.selectedProvider
            hasKey = KeychainService.hasAPIKey(for: selectedProvider.rawValue)
            modelOverride = LLMProvider.selectedModel ?? ""
            let prefs = TrackingPreferences.load()
            trackWindowTitles = prefs.trackWindowTitles
            trackBrowserURLs = prefs.trackBrowserURLs
            storeFullURLs = prefs.storeFullURLs
        }
        .sheet(isPresented: $showingCategoryRules) {
            CategoryRulesView()
        }
        .sheet(isPresented: $showingDiagnostics) {
            TrackingDiagnosticView()
        }
    }

    private func testKey() {
        isTesting = true
        testResult = nil
        Task {
            do {
                let provider = selectedProvider
                guard let key = KeychainService.getAPIKey(for: provider.rawValue) else {
                    await MainActor.run { testResult = "No key found"; isTesting = false }
                    return
                }

                let model = LLMProvider.effectiveModel
                var request: URLRequest

                if provider.isOpenAICompatible {
                    request = URLRequest(url: URL(string: provider.baseURL)!)
                    request.httpMethod = "POST"
                    request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    let body: [String: Any] = [
                        "model": model,
                        "messages": [["role": "user", "content": "Say OK"]],
                        "max_tokens": 5
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                } else {
                    request = URLRequest(url: URL(string: provider.baseURL)!)
                    request.httpMethod = "POST"
                    request.addValue(key, forHTTPHeaderField: "x-api-key")
                    request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    let body: [String: Any] = [
                        "model": model,
                        "max_tokens": 5,
                        "messages": [["role": "user", "content": "Say OK"]]
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                }

                request.timeoutInterval = 15
                let (_, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0

                await MainActor.run {
                    if status == 200 {
                        testResult = "Success"
                    } else {
                        testResult = "Failed (HTTP \(status))"
                    }
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "Error: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
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
