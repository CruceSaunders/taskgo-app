import Foundation
import FirebaseAuth

@MainActor
class XPViewModel: ObservableObject {
    @Published var totalXP: Int = 0
    @Published var level: Int = 1
    @Published var weeklyXP: Int = 0
    @Published var progressToNextLevel: Double = 0.0
    @Published var xpToNextLevel: Int = 0

    private let firestoreService = FirestoreService.shared

    func loadXP() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            if let profile = try await firestoreService.getUserProfile(userId: userId) {
                totalXP = profile.totalXP
                level = profile.level
                weeklyXP = profile.weeklyXP
                updateDerivedValues()
            }
        } catch {
            print("Error loading XP: \(error.localizedDescription)")
        }
    }

    func awardXP(activeMinutes: Int) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let earnedXP = XPSystem.calculateXP(activeMinutes: activeMinutes)
        guard earnedXP > 0 else { return }

        totalXP += earnedXP
        weeklyXP += earnedXP
        level = XPSystem.levelForXP(totalXP)
        updateDerivedValues()

        do {
            try await firestoreService.updateUserXP(
                userId: userId,
                totalXP: totalXP,
                level: level,
                weeklyXP: weeklyXP
            )
        } catch {
            print("Error saving XP: \(error.localizedDescription)")
        }
    }

    private func updateDerivedValues() {
        progressToNextLevel = XPSystem.progressToNextLevel(totalXP: totalXP)
        xpToNextLevel = XPSystem.xpToNextLevel(totalXP: totalXP)
    }
}
