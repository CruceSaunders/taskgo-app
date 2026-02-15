import Foundation
import FirebaseAuth
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let firestoreService = FirestoreService.shared

    init() {
        setupAuthStateListener()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                if let userId = user?.uid {
                    await self?.loadUserProfile(userId: userId)
                } else {
                    self?.userProfile = nil
                }
            }
        }
    }

    private func loadUserProfile(userId: String) async {
        do {
            userProfile = try await firestoreService.getUserProfile(userId: userId)
        } catch {
            print("Error loading user profile: \(error.localizedDescription)")
        }
    }

    func signUp(email: String, password: String, username: String, displayName: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // Check username availability first
            let available = try await firestoreService.isUsernameAvailable(username)
            guard available else {
                errorMessage = "Username '\(username)' is already taken"
                isLoading = false
                return
            }

            // Create auth account
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let userId = result.user.uid

            // Claim username
            try await firestoreService.claimUsername(username, userId: userId)

            // Create user profile
            let profile = UserProfile(
                email: email,
                username: username,
                displayName: displayName
            )
            try await firestoreService.createUserProfile(profile, userId: userId)

            // Create default task group
            let defaultGroup = TaskGroup(
                name: "Tasks",
                order: 0,
                isDefault: true
            )
            _ = try await firestoreService.createGroup(defaultGroup, userId: userId)

            userProfile = profile
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            userProfile = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
