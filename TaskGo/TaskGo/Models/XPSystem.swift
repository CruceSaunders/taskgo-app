import Foundation

/// XP and leveling system for TaskGo!
/// - 1 XP per minute of verified active work during Task Go
/// - 100 levels with progressive difficulty
/// - XP awarded on actual time worked, not estimated time
struct XPSystem {
    /// Calculate the total XP required to reach a given level
    /// Uses a quadratic curve: each level requires increasingly more XP
    /// Level 1: 0 XP (starting level)
    /// Level 2: 10 XP
    /// Level 10: ~450 XP
    /// Level 50: ~12,250 XP
    /// Level 100: ~49,500 XP
    static func xpRequiredForLevel(_ level: Int) -> Int {
        guard level > 1 else { return 0 }
        // Quadratic formula: XP = 5 * (level - 1)^2 + 5 * (level - 1)
        let n = level - 1
        return 5 * n * n + 5 * n
    }

    /// Calculate what level a user is at given their total XP
    static func levelForXP(_ totalXP: Int) -> Int {
        var level = 1
        while level < 100 && totalXP >= xpRequiredForLevel(level + 1) {
            level += 1
        }
        return level
    }

    /// Calculate progress toward the next level (0.0 to 1.0)
    static func progressToNextLevel(totalXP: Int) -> Double {
        let currentLevel = levelForXP(totalXP)
        if currentLevel >= 100 { return 1.0 }

        let currentLevelXP = xpRequiredForLevel(currentLevel)
        let nextLevelXP = xpRequiredForLevel(currentLevel + 1)
        let xpIntoLevel = totalXP - currentLevelXP
        let xpNeeded = nextLevelXP - currentLevelXP

        guard xpNeeded > 0 else { return 0.0 }
        return Double(xpIntoLevel) / Double(xpNeeded)
    }

    /// Calculate XP remaining to reach the next level
    static func xpToNextLevel(totalXP: Int) -> Int {
        let currentLevel = levelForXP(totalXP)
        if currentLevel >= 100 { return 0 }

        let nextLevelXP = xpRequiredForLevel(currentLevel + 1)
        return nextLevelXP - totalXP
    }

    /// Calculate XP earned from a Task Go session
    /// - Parameter activeMinutes: Number of minutes with verified activity
    /// - Returns: XP earned (1 XP per active minute)
    static func calculateXP(activeMinutes: Int) -> Int {
        return max(0, activeMinutes)
    }
}
