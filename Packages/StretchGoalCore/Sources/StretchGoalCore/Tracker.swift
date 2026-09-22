import Foundation

/// Minutes-since-midnight window during which sitting is tracked.
public struct WorkHours: Codable, Hashable, Sendable {
    public var startMinute: Int
    public var endMinute: Int

    public init(startMinute: Int = 7 * 60, endMinute: Int = 18 * 60) {
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let minute = c.hour! * 60 + c.minute!
        return minute >= startMinute && minute < endMinute
    }
}

public struct TrackerConfig: Codable, Hashable, Sendable {
    /// Idle time after which the person is considered away from the desk.
    public var idleThreshold: TimeInterval
    /// A sitting segment at least this long counts as having earned a break when it ends.
    public var minSitForBreak: TimeInterval
    /// Sitting time after which the first nudge fires.
    public var nudgeAfter: TimeInterval
    /// Interval between repeat nudges while still sitting.
    public var nudgeRepeat: TimeInterval
    /// `nil` tracks all day.
    public var workHours: WorkHours?

    public init(
        idleThreshold: TimeInterval = 180,
        minSitForBreak: TimeInterval = 20 * 60,
        nudgeAfter: TimeInterval = 45 * 60,
        nudgeRepeat: TimeInterval = 15 * 60,
        workHours: WorkHours? = WorkHours()
    ) {
        self.idleThreshold = idleThreshold
        self.minSitForBreak = minSitForBreak
        self.nudgeAfter = nudgeAfter
        self.nudgeRepeat = nudgeRepeat
        self.workHours = workHours
    }

    public static let standard = TrackerConfig()
}

public struct TrackerState: Codable, Hashable, Sendable {
    public var lastSample: Date?
    public var sitStart: Date?
    public var lastNudgeAt: Date?
    /// First keyboard/mouse activity seen today. Anchors "you haven't had water in an hour".
    public var firstActiveAt: Date?
    public var activeSeconds: Int
    public var longestSitSeconds: Int
    public var detectedBreaks: Int

    public init(lastSample: Date? = nil, sitStart: Date? = nil, lastNudgeAt: Date? = nil, firstActiveAt: Date? = nil,
                activeSeconds: Int = 0, longestSitSeconds: Int = 0, detectedBreaks: Int = 0) {
        self.lastSample = lastSample
        self.sitStart = sitStart
        self.lastNudgeAt = lastNudgeAt
        self.firstActiveAt = firstActiveAt
        self.activeSeconds = activeSeconds
        self.longestSitSeconds = longestSitSeconds
        self.detectedBreaks = detectedBreaks
    }

    public func currentSit(at now: Date) -> TimeInterval {
        sitStart.map { max(0, now.timeIntervalSince($0)) } ?? 0
    }
}

public enum TrackerEvent: Hashable, Sendable {
    case breakDetected(sitSeconds: Int)
    case nudge(sitSeconds: Int)
}

/// Pure state machine fed with periodic idle samples. All wall-clock and input-device access
/// stays in the app so this can be tested with synthetic time.
public enum Tracker {
    public static func advance(
        _ state: inout TrackerState,
        now: Date,
        idleSeconds: TimeInterval,
        locked: Bool,
        config: TrackerConfig = .standard,
        calendar: Calendar = .current
    ) -> [TrackerEvent] {
        var events: [TrackerEvent] = []
        defer { state.lastSample = now }

        // A gap longer than the idle threshold means the machine slept or the app was not running.
        if let last = state.lastSample, now.timeIntervalSince(last) > config.idleThreshold {
            endSegment(&state, at: last, config: config, events: &events)
        }

        let inWorkHours = config.workHours?.contains(now, calendar: calendar) ?? true
        let active = !locked && idleSeconds < config.idleThreshold && inWorkHours

        guard active else {
            let endedAt = locked ? now : now.addingTimeInterval(-idleSeconds)
            endSegment(&state, at: endedAt, config: config, events: &events)
            return events
        }

        if state.sitStart == nil {
            state.sitStart = now.addingTimeInterval(-idleSeconds)
        }
        if state.firstActiveAt == nil {
            state.firstActiveAt = now
        }
        if let last = state.lastSample, now.timeIntervalSince(last) <= config.idleThreshold {
            state.activeSeconds += Int(now.timeIntervalSince(last).rounded())
        }

        let sit = state.currentSit(at: now)
        state.longestSitSeconds = max(state.longestSitSeconds, Int(sit))

        if sit >= config.nudgeAfter {
            let due = state.lastNudgeAt.map { now.timeIntervalSince($0) >= config.nudgeRepeat } ?? true
            if due {
                state.lastNudgeAt = now
                events.append(.nudge(sitSeconds: Int(sit)))
            }
        }
        return events
    }

    /// Call when the person completes a movement session. Ends the sitting segment without
    /// counting a detected break: the caller credits the completed session instead.
    public static func recordMovement(_ state: inout TrackerState, at now: Date) {
        if let start = state.sitStart {
            state.longestSitSeconds = max(state.longestSitSeconds, Int(now.timeIntervalSince(start)))
        }
        state.sitStart = nil
        state.lastNudgeAt = nil
    }

    private static func endSegment(_ state: inout TrackerState, at endedAt: Date, config: TrackerConfig, events: inout [TrackerEvent]) {
        guard let start = state.sitStart else { return }
        let length = max(0, endedAt.timeIntervalSince(start))
        state.longestSitSeconds = max(state.longestSitSeconds, Int(length))
        if length >= config.minSitForBreak {
            state.detectedBreaks += 1
            events.append(.breakDetected(sitSeconds: Int(length)))
        }
        state.sitStart = nil
        state.lastNudgeAt = nil
    }
}
