import Foundation

/// Everything the app stores locally for one day. Only `summary` is ever shared.
public struct LocalDay: Codable, Hashable, Sendable {
    public var summary: DaySummary
    public var tracker: TrackerState
    public var waterEntriesMl: [Int]
    public var completedSessions: [SessionKind]
    /// Step milestones already celebrated today, so each fires once.
    public var celebratedMilestones: [Int]
    public var celebratedAllGoals: Bool

    public init(summary: DaySummary, tracker: TrackerState = TrackerState(), waterEntriesMl: [Int] = [],
                completedSessions: [SessionKind] = [], celebratedMilestones: [Int] = [], celebratedAllGoals: Bool = false) {
        self.summary = summary
        self.tracker = tracker
        self.waterEntriesMl = waterEntriesMl
        self.completedSessions = completedSessions
        self.celebratedMilestones = celebratedMilestones
        self.celebratedAllGoals = celebratedAllGoals
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = try c.decode(DaySummary.self, forKey: .summary)
        tracker = try c.decode(TrackerState.self, forKey: .tracker)
        waterEntriesMl = try c.decode([Int].self, forKey: .waterEntriesMl)
        completedSessions = try c.decode([SessionKind].self, forKey: .completedSessions)
        celebratedMilestones = try c.decodeIfPresent([Int].self, forKey: .celebratedMilestones) ?? []
        celebratedAllGoals = try c.decodeIfPresent(Bool.self, forKey: .celebratedAllGoals) ?? false
    }

    public var date: DayKey { summary.date }
    public var waterMl: Int { waterEntriesMl.reduce(0, +) }

    /// Recomputes the shared summary from local facts so the two can never drift.
    public mutating func refreshSummary(now: Date) {
        summary.breaks = tracker.detectedBreaks + completedSessions.filter { $0.credit == .breakTaken }.count
        summary.mindful = completedSessions.filter { $0.credit == .mindful }.count
        summary.eyeRests = completedSessions.filter { $0.credit == .eyeRest }.count
        summary.waterMl = waterMl
        summary.activeSeconds = tracker.activeSeconds
        summary.longestSitSeconds = max(tracker.longestSitSeconds, Int(tracker.currentSit(at: now)))
        summary.updatedAt = now
    }
}
