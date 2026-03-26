import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var xpVM: XPViewModel

    @State private var selectedProvider: LLMProvider = .selectedProvider
    @State private var apiKeyInput = ""
    @State private var hasKey = LLMProvider.isConfigured
    @State private var focusModel = UserDefaults.standard.string(forKey: "focusGuard_model") ?? ""

    var body: some View {
        ScrollView {
        VStack(spacing: 16) {
            Spacer()

            // Avatar / name
            VStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.calmTeal.opacity(0.8))

                if let profile = authVM.userProfile {
                    Text(profile.displayName)
                        .font(.system(size: 16, weight: .semibold))
                    Text("@\(profile.username)")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.6))
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
                            .foregroundStyle(.primary.opacity(0.55))
                        Spacer()
                        if xpVM.level < 100 {
                            Text("\(xpVM.xpToNextLevel) XP to next level")
                                .font(.system(size: 10))
                                .foregroundStyle(.primary.opacity(0.55))
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

            // AI Provider
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Provider")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.6))

                Picker("", selection: $selectedProvider) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: selectedProvider) { _, newValue in
                    LLMProvider.selectedProvider = newValue
                    hasKey = KeychainService.hasAPIKey(for: newValue.rawValue)
                    apiKeyInput = ""
                }

                if hasKey {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                        Text("\(selectedProvider.displayName) key saved")
                            .font(.system(size: 10))
                            .foregroundStyle(.primary.opacity(0.6))
                        Spacer()
                        Button("Remove") {
                            KeychainService.deleteAPIKey(for: selectedProvider.rawValue)
                            hasKey = false
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .buttonStyle(.plain)
                    }
                } else {
                    HStack(spacing: 6) {
                        SecureField(selectedProvider.keyPlaceholder, text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                        Button("Save") {
                            let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !key.isEmpty else { return }
                            KeychainService.saveAPIKey(key, for: selectedProvider.rawValue)
                            hasKey = true
                            apiKeyInput = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.calmTeal)
                        .controlSize(.small)
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                HStack(spacing: 6) {
                    Text("Focus Guard model")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.5))
                    TextField("e.g. claude-haiku-4-5-20250620", text: $focusModel)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 10))
                        .onChange(of: focusModel) { _, newValue in
                            UserDefaults.standard.set(newValue.isEmpty ? nil : newValue, forKey: "focusGuard_model")
                        }
                }

                if !hasKey {
                    Text("An AI key is required for Focus Guard and calendar conversion.")
                        .font(.system(size: 9))
                        .foregroundStyle(.primary.opacity(0.35))
                }
            }
            .padding(.horizontal, 16)

            // API Keys
            APIKeyView()
                .padding(.horizontal, 16)

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
}
