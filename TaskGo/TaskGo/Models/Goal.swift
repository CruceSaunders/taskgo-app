import Foundation
import FirebaseFirestore

struct Milestone: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var isComplete: Bool
    var completedAt: Date?
    var position: Int

    init(id: String = UUID().uuidString,
         title: String,
         isComplete: Bool = false,
         completedAt: Date? = nil,
         position: Int = 0) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
        self.completedAt = completedAt
        self.position = position
    }
}

struct Goal: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var title: String
    var notes: String
    var milestones: [Milestone]

    /// Date the user committed to starting (user-set).
    var startDate: Date
    /// User's best guess of when they'll finish.
    var estimatedEndDate: Date?
    /// Date the user actually marked the goal complete.
    var completedAt: Date?

    /// Total seconds accumulated by the stopwatch across all sessions.
    /// Editable by the user (honor system).
    var totalElapsedSeconds: Int

    /// Wall-clock date that the stopwatch was last started, if currently running.
    /// `nil` means the stopwatch is stopped. The current displayed elapsed time
    /// is `totalElapsedSeconds + (now - stopwatchStartedAt)` when running.
    var stopwatchStartedAt: Date?

    var createdAt: Date
    var updatedAt: Date

    init(id: String? = nil,
         title: String,
         notes: String = "",
         milestones: [Milestone] = [],
         startDate: Date = Date(),
         estimatedEndDate: Date? = nil,
         completedAt: Date? = nil,
         totalElapsedSeconds: Int = 0,
         stopwatchStartedAt: Date? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.notes = notes
        self.milestones = milestones
        self.startDate = startDate
        self.estimatedEndDate = estimatedEndDate
        self.completedAt = completedAt
        self.totalElapsedSeconds = totalElapsedSeconds
        self.stopwatchStartedAt = stopwatchStartedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func == (lhs: Goal, rhs: Goal) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.notes == rhs.notes
            && lhs.milestones == rhs.milestones
            && lhs.startDate == rhs.startDate
            && lhs.estimatedEndDate == rhs.estimatedEndDate
            && lhs.completedAt == rhs.completedAt
            && lhs.totalElapsedSeconds == rhs.totalElapsedSeconds
            && lhs.stopwatchStartedAt == rhs.stopwatchStartedAt
    }

    // MARK: - Derived

    var isCompleted: Bool { completedAt != nil }

    var isStopwatchRunning: Bool { stopwatchStartedAt != nil }

    /// Total elapsed seconds taking into account a currently-running stopwatch.
    /// `now` lets callers stabilise the value for display.
    func liveElapsedSeconds(now: Date = Date()) -> Int {
        guard let started = stopwatchStartedAt else { return totalElapsedSeconds }
        let delta = max(0, Int(now.timeIntervalSince(started)))
        return totalElapsedSeconds + delta
    }

    var completedMilestoneCount: Int {
        milestones.filter { $0.isComplete }.count
    }

    var progressFraction: Double {
        guard !milestones.isEmpty else { return isCompleted ? 1.0 : 0.0 }
        return Double(completedMilestoneCount) / Double(milestones.count)
    }

    /// Estimated total duration in days from start to estimated end. `nil` if no estimate.
    var estimatedDurationDays: Int? {
        guard let end = estimatedEndDate else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let endDay = cal.startOfDay(for: end)
        return cal.dateComponents([.day], from: start, to: endDay).day
    }

    /// Actual duration in days from start to completion. `nil` if not completed.
    var actualDurationDays: Int? {
        guard let completed = completedAt else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let endDay = cal.startOfDay(for: completed)
        return cal.dateComponents([.day], from: start, to: endDay).day
    }

    /// Difference between actual and estimated days (positive = late, negative = early). `nil` if not completed or no estimate.
    var dayDelta: Int? {
        guard let actual = actualDurationDays, let estimated = estimatedDurationDays else { return nil }
        return actual - estimated
    }
}

extension Goal {
    static func formatElapsed(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    static func formatElapsedLong(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}
