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
    public var waterTaps: Int
    public var mindful: Int
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
        waterTaps: Int = 0,
        mindful: Int = 0,
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
        self.waterTaps = waterTaps
        self.mindful = mindful
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
            result.waterTaps = max(result.waterTaps, s.waterTaps)
            result.mindful = max(result.mindful, s.mindful)
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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        memberId = try c.decode(String.self, forKey: .memberId)
        deviceId = try c.decode(String.self, forKey: .deviceId)
        date = try c.decode(DayKey.self, forKey: .date)
        timeZone = try c.decode(String.self, forKey: .timeZone)
        breaks = try c.decode(Int.self, forKey: .breaks)
        waterTaps = try c.decode(Int.self, forKey: .waterTaps)
        mindful = try c.decode(Int.self, forKey: .mindful)
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
