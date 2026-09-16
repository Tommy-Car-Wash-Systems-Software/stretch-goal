import Foundation

public struct WaterEntry: Codable, Hashable, Sendable {
    public var ml: Int
    public var at: Date

    public init(ml: Int, at: Date) {
        self.ml = ml
        self.at = at
    }
}

/// Everything the app stores locally for one day. Only `summary` is ever shared.
public struct LocalDay: Codable, Hashable, Sendable {
    public var summary: DaySummary
    public var tracker: TrackerState
    public var waterEntries: [WaterEntry]
    public var completedSessions: [SessionKind]
    /// Step milestones already celebrated today, so each fires once.
    public var celebratedMilestones: [Int]
    public var celebratedAllGoals: Bool

    public init(summary: DaySummary, tracker: TrackerState = TrackerState(), waterEntries: [WaterEntry] = [],
                completedSessions: [SessionKind] = [], celebratedMilestones: [Int] = [], celebratedAllGoals: Bool = false) {
        self.summary = summary
        self.tracker = tracker
        self.waterEntries = waterEntries
        self.completedSessions = completedSessions
        self.celebratedMilestones = celebratedMilestones
        self.celebratedAllGoals = celebratedAllGoals
    }

    private enum LegacyKeys: String, CodingKey { case waterEntriesMl }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = try c.decode(DaySummary.self, forKey: .summary)
        tracker = try c.decode(TrackerState.self, forKey: .tracker)
        if let entries = try c.decodeIfPresent([WaterEntry].self, forKey: .waterEntries) {
            waterEntries = entries
        } else {
            // Untimestamped legacy taps: date them at the start of the day so they never trip the burst limit.
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            let dawn = summary.date.date()
            waterEntries = (try legacy.decodeIfPresent([Int].self, forKey: .waterEntriesMl) ?? []).map { WaterEntry(ml: $0, at: dawn) }
        }
        completedSessions = try c.decode([SessionKind].self, forKey: .completedSessions)
        celebratedMilestones = try c.decodeIfPresent([Int].self, forKey: .celebratedMilestones) ?? []
        celebratedAllGoals = try c.decodeIfPresent(Bool.self, forKey: .celebratedAllGoals) ?? false
    }

    public var date: DayKey { summary.date }
    public var waterMl: Int { waterEntries.reduce(0) { $0 + $1.ml } }

    /// Water logged within `window` seconds before `now`.
    public func waterMl(within window: TimeInterval, before now: Date) -> Int {
        waterEntries.filter { now.timeIntervalSince($0.at) < window }.reduce(0) { $0 + $1.ml }
    }

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
