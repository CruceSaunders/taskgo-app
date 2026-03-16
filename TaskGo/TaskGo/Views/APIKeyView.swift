import SwiftUI
import FirebaseAuth

struct APIKeyView: View {
    @State private var keys: [[String: Any]] = []
    @State private var isLoading = false
    @State private var showGenerate = false
    @State private var newKeyLabel = ""
    @State private var generatedKey: String?
    @State private var errorMessage: String?

    private var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("API Keys")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                if isSignedIn {
                    Button(action: { showGenerate = true }) {
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

            Text("Use API keys to connect external tools to your TaskGo account.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            if !isSignedIn {
                Text("Sign in to manage API keys")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .padding(.vertical, 8)
            } else if isLoading {
                HStack {
                    Spacer()
                    ProgressView().scaleEffect(0.7)
                    Spacer()
                }
            } else if keys.isEmpty {
                Text("No API keys yet")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(keys.indices, id: \.self) { i in
                        keyRow(keys[i])
                    }
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(8)
        .onAppear {
            if isSignedIn { loadKeys() }
        }
        .sheet(isPresented: $showGenerate) {
            generateSheet
        }
        .sheet(item: Binding(
            get: { generatedKey.map { GeneratedKeyWrapper(key: $0) } },
            set: { generatedKey = $0?.key }
        )) { wrapper in
            generatedKeySheet(wrapper.key)
        }
    }

    private func keyRow(_ key: [String: Any]) -> some View {
        let prefix = key["prefix"] as? String ?? "tg_sk_..."
        let label = key["label"] as? String ?? "API Key"
        let lastUsed = key["lastUsedAt"] as? String

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                HStack(spacing: 4) {
                    Text(prefix + "...")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if let lastUsed = lastUsed {
                        Text("Used \(formatDate(lastUsed))")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                }
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

    private var generateSheet: some View {
        VStack(spacing: 16) {
            Text("Generate API Key")
                .font(.system(size: 14, weight: .bold))

            TextField("Label (e.g. My OpenClaw Agent)", text: $newKeyLabel)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            HStack {
                Button("Cancel") { showGenerate = false }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Generate") {
                    generateKey()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.calmTeal)
                .disabled(newKeyLabel.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func generatedKeySheet(_ key: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.calmTeal)

            Text("Your API Key")
                .font(.system(size: 14, weight: .bold))

            Text("Copy this key now. You won't see it again.")
                .font(.system(size: 10))
                .foregroundStyle(.orange)

            HStack {
                Text(key)
                    .font(.system(size: 10, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(4)

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(key, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Base URL:")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("https://us-central1-taskgo-prod.cloudfunctions.net/api")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.04))
            .cornerRadius(4)

            Button("Done") {
                generatedKey = nil
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.calmTeal)
        }
        .padding(20)
        .frame(width: 380)
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
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func generateKey() {
        let label = newKeyLabel.trimmingCharacters(in: .whitespaces)
        showGenerate = false
        isLoading = true
        errorMessage = nil
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
                    errorMessage = error.localizedDescription
                    isLoading = false
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
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func formatDate(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        guard let date = fmt.date(from: iso) else { return iso }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: date, relativeTo: Date())
    }
}

struct GeneratedKeyWrapper: Identifiable {
    let key: String
    var id: String { key }
}
