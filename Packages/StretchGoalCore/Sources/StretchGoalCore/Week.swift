import Foundation

/// A Monday-through-Sunday week. Leaderboards are scored per week.
public struct Week: Hashable, Sendable {
    public let monday: DayKey

    public init(containing day: DayKey, calendar: Calendar = .current) {
        var cal = calendar
        cal.firstWeekday = 2
        let date = day.date(in: cal)
        let weekday = cal.component(.weekday, from: date) // 1 = Sunday ... 7 = Saturday
        let offsetFromMonday = (weekday + 5) % 7
        monday = day.adding(days: -offsetFromMonday, calendar: cal)
    }

    public var sunday: DayKey { monday.adding(days: 6) }

    public var days: [DayKey] { (0..<7).map { monday.adding(days: $0) } }

    public func contains(_ day: DayKey) -> Bool { day >= monday && day <= sunday }

    public var previous: Week { Week(containing: monday.adding(days: -7)) }
}
