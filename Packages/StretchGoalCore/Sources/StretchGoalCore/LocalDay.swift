import Foundation

/// Everything the app stores locally for one day. Only `summary` is ever shared.
public struct LocalDay: Codable, Hashable, Sendable {
    public var summary: DaySummary
    public var tracker: TrackerState
    public var waterEntriesMl: [Int]
    public var completedSessions: [SessionKind]

    public init(summary: DaySummary, tracker: TrackerState = TrackerState(), waterEntriesMl: [Int] = [], completedSessions: [SessionKind] = []) {
        self.summary = summary
        self.tracker = tracker
        self.waterEntriesMl = waterEntriesMl
        self.completedSessions = completedSessions
    }

    public var date: DayKey { summary.date }
    public var waterMl: Int { waterEntriesMl.reduce(0, +) }

    /// Recomputes the shared summary from local facts so the two can never drift.
    public mutating func refreshSummary(now: Date) {
        summary.breaks = tracker.detectedBreaks + completedSessions.filter { $0.credit == .breakTaken }.count
        summary.mindful = completedSessions.filter { $0.credit == .mindful }.count
        summary.waterTaps = waterEntriesMl.count
        summary.activeSeconds = tracker.activeSeconds
        summary.longestSitSeconds = max(tracker.longestSitSeconds, Int(tracker.currentSit(at: now)))
        summary.updatedAt = now
    }
}
