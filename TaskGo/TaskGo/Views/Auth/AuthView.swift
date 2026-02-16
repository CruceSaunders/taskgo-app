import SwiftUI

struct AuthView: View {
    @State private var isSignUp = false

    var body: some View {
        VStack(spacing: 0) {
            if isSignUp {
                SignUpView(switchToSignIn: { isSignUp = false })
            } else {
                SignInView(switchToSignUp: { isSignUp = true })
            }
        }
    }
}

struct SignInView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    var switchToSignUp: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Logo / Title
            VStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.calmTeal)
                Text("TaskGo!")
                    .font(.system(size: 24, weight: .bold))
                Text("Stay focused. Get things done.")
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.6))
            }

            Spacer()

            // Form
            VStack(spacing: 10) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
            }
            .padding(.horizontal, 24)

            if let error = authVM.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
            }

            Button(action: {
                Task {
                    await authVM.signIn(email: email, password: password)
                }
            }) {
                if authVM.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.calmTeal)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .disabled(email.isEmpty || password.isEmpty || authVM.isLoading)

            Button("Don't have an account? Sign Up") {
                switchToSignUp()
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(Color.calmTeal)

            Spacer()
        }
    }
}

struct SignUpView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var displayName = ""
    var switchToSignIn: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.calmTeal)
                Text("Create Account")
                    .font(.system(size: 20, weight: .bold))
            }

            VStack(spacing: 10) {
                TextField("Display Name", text: $displayName)
                    .textFieldStyle(.roundedBorder)

                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)

                SecureField("Password (min 6 characters)", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
            }
            .padding(.horizontal, 24)

            if let error = authVM.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
            }

            Button(action: {
                Task {
                    await authVM.signUp(
                        email: email,
                        password: password,
                        username: username,
                        displayName: displayName
                    )
                }
            }) {
                if authVM.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Create Account")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.calmTeal)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .disabled(email.isEmpty || password.count < 6 || username.isEmpty || displayName.isEmpty || authVM.isLoading)

            Button("Already have an account? Sign In") {
                switchToSignIn()
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(Color.calmTeal)

            Spacer()
        }
    }
}
