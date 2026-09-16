import Foundation
@testable import StretchGoalCore

enum Fixtures {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }

    static func day(_ s: String) -> DayKey { DayKey(string: s)! }

    static func summary(
        _ date: String, member: String = "brianp", device: String = "d1",
        breaks: Int = 0, water: Int = 0, mindful: Int = 0, updatedAt: Date = Date(timeIntervalSince1970: 1_000)
    ) -> DaySummary {
        DaySummary(memberId: member, deviceId: device, date: day(date), timeZone: "America/Chicago",
                   breaks: breaks, waterTaps: water, mindful: mindful, updatedAt: updatedAt)
    }

    /// All three default goals met.
    static func perfect(_ date: String, member: String = "brianp") -> DaySummary {
        summary(date, member: member, breaks: 6, water: 8, mindful: 2)
    }

    static func history(_ days: [DaySummary]) -> [DayKey: DaySummary] {
        Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
    }
}
