import SwiftUI
import FirebaseAuth

struct APIKeyView: View {
    @State private var keys: [[String: Any]] = []
    @State private var isLoading = false
    @State private var newKeyLabel = ""
    @State private var generatedKey: String?
    @State private var errorMessage: String?
    @State private var showLabelField = false

    private var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("API Keys")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                if isSignedIn && generatedKey == nil {
                    Button(action: { showLabelField.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 9))
                            Text("New Key")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.calmTeal)
                        .foregroundStyle(.white)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Connect external tools (like AI agents) to your account.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            // Generated key display
            if let key = generatedKey {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.calmTeal)
                        Text("Copy this key now. You won't see it again.")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.orange)
                    }

                    HStack {
                        Text(key)
                            .font(.system(size: 9, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(1)
                        Spacer()
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(key, forType: .string)
                        }) {
                            Text("Copy")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.calmTeal)
                        .controlSize(.mini)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(4)

                    Text("Base URL: https://us-central1-taskgo-prod.cloudfunctions.net/api")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Button("Done") {
                        generatedKey = nil
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)
                }
                .padding(8)
                .background(Color.calmTeal.opacity(0.05))
                .cornerRadius(6)
            }

            // Generate form
            if showLabelField && generatedKey == nil {
                HStack(spacing: 6) {
                    TextField("Label (e.g. My AI Agent)", text: $newKeyLabel)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                    Button("Generate") {
                        generateKey()
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(Color.calmTeal)
                    .controlSize(.small)
                    .disabled(newKeyLabel.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }

            // Error
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
                    .padding(.vertical, 2)
            }

            // Loading
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView().scaleEffect(0.7)
                    Text("Working...").font(.system(size: 9)).foregroundStyle(.secondary)
                    Spacer()
                }
            }

            // Existing keys
            if !isSignedIn {
                Text("Sign in to manage API keys")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.6))
            } else if !keys.isEmpty {
                VStack(spacing: 4) {
                    ForEach(keys.indices, id: \.self) { i in
                        keyRow(keys[i])
                    }
                }
            } else if !isLoading {
                Text("No API keys yet")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(8)
        .onAppear {
            if isSignedIn { loadKeys() }
        }
    }

    private func keyRow(_ key: [String: Any]) -> some View {
        let prefix = key["prefix"] as? String ?? "tg_sk_..."
        let label = key["label"] as? String ?? "API Key"

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                Text(prefix + "...")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Revoke") {
                revokeKey(prefix: prefix)
            }
            .font(.system(size: 9))
            .foregroundStyle(.red)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(4)
    }

    private func loadKeys() {
        guard isSignedIn else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await FirestoreService.shared.listApiKeys()
                await MainActor.run {
                    keys = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Load failed: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func generateKey() {
        let label = newKeyLabel.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        showLabelField = false
        Task {
            do {
                let result = try await FirestoreService.shared.generateApiKey(label: label)
                await MainActor.run {
                    generatedKey = result.key
                    newKeyLabel = ""
                    isLoading = false
                    loadKeys()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Generate failed: \(error.localizedDescription)"
                    isLoading = false
                    showLabelField = true
                }
            }
        }
    }

    private func revokeKey(prefix: String) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await FirestoreService.shared.revokeApiKey(prefix: prefix)
                await MainActor.run {
                    keys.removeAll { ($0["prefix"] as? String) == prefix }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Revoke failed: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}
