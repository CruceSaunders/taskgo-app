import Foundation
import FirebaseAuth

/// One-time cleanup of artifacts left over from the removed Focus + Activity
/// tracking features. Runs once per user; the flag is stored locally.
enum LegacyActivityCleanup {
    private static let didCleanFirestoreKey = "legacyActivity_didCleanFirestore"
    private static let didCleanLocalKey = "legacyActivity_didCleanLocal"

    static func runIfNeeded() {
        cleanLocalArtifacts()
        cleanFirestoreActivityDays()
    }

    // MARK: - Local

    private static func cleanLocalArtifacts() {
        if UserDefaults.standard.bool(forKey: didCleanLocalKey) { return }

        let fm = FileManager.default
        let activityDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".taskgo")
            .appendingPathComponent("activity")
        try? fm.removeItem(at: activityDir)

        // Defaults written by the old tracking + focus subsystems.
        let legacyDefaultsKeys = [
            "focusGuard_model",
            "hasSeenActivityPermission",
            "trackingPreferences",
            "trackingPreferences.v1",
            "categoryRules",
            "categoryRules.v1",
        ]
        for key in legacyDefaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        UserDefaults.standard.set(true, forKey: didCleanLocalKey)
    }

    // MARK: - Firestore

    private static func cleanFirestoreActivityDays() {
        if UserDefaults.standard.bool(forKey: didCleanFirestoreKey) { return }
        guard let userId = Auth.auth().currentUser?.uid else {
            // Try again on next launch once the user is signed in.
            return
        }
        Task.detached(priority: .background) {
            do {
                try await FirestoreService.shared.deleteAllActivityDays(userId: userId)
                UserDefaults.standard.set(true, forKey: didCleanFirestoreKey)
                print("[LegacyActivityCleanup] Cleared legacy activityDays for user \(userId).")
            } catch {
                print("[LegacyActivityCleanup] Could not clear activityDays: \(error.localizedDescription)")
            }
        }
    }
}
