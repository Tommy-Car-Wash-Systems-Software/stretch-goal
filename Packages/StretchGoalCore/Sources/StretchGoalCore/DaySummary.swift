import Foundation

/// The only record that leaves a member's machine. One file per member per day per device.
public struct DaySummary: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var memberId: String
    public var deviceId: String
    public var date: DayKey
    public var timeZone: String
    public var breaks: Int
    /// Millilitres of water logged. Earlier files carried `waterTaps`; those decode as taps × 250.
    public var waterMl: Int
    /// Completed breathing sessions.
    public var mindful: Int
    /// Completed 20-second eye rests (the 20-20-20 rule). Added later; decodes as 0 when absent.
    public var eyeRests: Int
    /// Daily step total, entered manually on macOS. Added after v1 files existed, so it decodes
    /// as 0 when absent.
    public var steps: Int
    public var activeSeconds: Int
    public var longestSitSeconds: Int
    public var updatedAt: Date

    public init(
        memberId: String,
        deviceId: String,
        date: DayKey,
        timeZone: String = TimeZone.current.identifier,
        breaks: Int = 0,
        waterMl: Int = 0,
        mindful: Int = 0,
        eyeRests: Int = 0,
        steps: Int = 0,
        activeSeconds: Int = 0,
        longestSitSeconds: Int = 0,
        updatedAt: Date = .now
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.memberId = memberId
        self.deviceId = deviceId
        self.date = date
        self.timeZone = timeZone
        self.breaks = breaks
        self.waterMl = waterMl
        self.mindful = mindful
        self.eyeRests = eyeRests
        self.steps = steps
        self.activeSeconds = activeSeconds
        self.longestSitSeconds = longestSitSeconds
        self.updatedAt = updatedAt
    }

    /// Combines summaries for the same member and day from several devices.
    /// Counts take the max rather than the sum so two active Macs do not double-count.
    public static func merge(_ summaries: [DaySummary]) -> DaySummary? {
        guard var result = summaries.first else { return nil }
        for s in summaries.dropFirst() {
            result.breaks = max(result.breaks, s.breaks)
            result.waterMl = max(result.waterMl, s.waterMl)
            result.mindful = max(result.mindful, s.mindful)
            result.eyeRests = max(result.eyeRests, s.eyeRests)
            result.steps = max(result.steps, s.steps)
            result.activeSeconds = max(result.activeSeconds, s.activeSeconds)
            result.longestSitSeconds = max(result.longestSitSeconds, s.longestSitSeconds)
            if s.updatedAt > result.updatedAt {
                result.updatedAt = s.updatedAt
                result.deviceId = s.deviceId
            }
        }
        return result
    }

    private enum LegacyKeys: String, CodingKey { case waterTaps }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        memberId = try c.decode(String.self, forKey: .memberId)
        deviceId = try c.decode(String.self, forKey: .deviceId)
        date = try c.decode(DayKey.self, forKey: .date)
        timeZone = try c.decode(String.self, forKey: .timeZone)
        breaks = try c.decode(Int.self, forKey: .breaks)
        waterMl = try c.decodeIfPresent(Int.self, forKey: .waterMl)
            ?? (try legacy.decodeIfPresent(Int.self, forKey: .waterTaps) ?? 0) * 250
        mindful = try c.decode(Int.self, forKey: .mindful)
        eyeRests = try c.decodeIfPresent(Int.self, forKey: .eyeRests) ?? 0
        steps = try c.decodeIfPresent(Int.self, forKey: .steps) ?? 0
        activeSeconds = try c.decode(Int.self, forKey: .activeSeconds)
        longestSitSeconds = try c.decode(Int.self, forKey: .longestSitSeconds)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }
}

public struct MemberProfile: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var memberId: String
    public var nickname: String
    public var joined: Date

    public init(memberId: String, nickname: String, joined: Date = .now) {
        self.schemaVersion = Self.currentSchemaVersion
        self.memberId = memberId
        self.nickname = nickname
        self.joined = joined
    }
}
