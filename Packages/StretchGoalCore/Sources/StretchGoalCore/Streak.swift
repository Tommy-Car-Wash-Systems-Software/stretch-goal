import Foundation

public enum Streak {
    /// Consecutive weekdays ending at `day` on which all goals were met.
    /// Weekend days are skipped: they neither extend nor break a streak.
    /// If `day` itself is a weekday without all goals met, the streak is 0.
    public static func ending(
        at day: DayKey,
        history: [DayKey: DaySummary],
        rules: ScoringRules = .standard,
        calendar: Calendar = .current
    ) -> Int {
        var cursor = day
        var count = 0
        var lookback = 0
        while lookback < 400 {
            defer { cursor = cursor.adding(days: -1, calendar: calendar); lookback += 1 }
            if cursor.isWeekend(calendar: calendar) { continue }
            guard let summary = history[cursor], rules.allGoalsMet(summary) else { break }
            count += 1
        }
        return count
    }

    /// Streak carried into `day` from the preceding weekdays. Drives the multiplier so that
    /// day N of a run is scored at (N-1) steps: a lone perfect day earns no multiplier.
    public static func carried(
        into day: DayKey,
        history: [DayKey: DaySummary],
        rules: ScoringRules = .standard,
        calendar: Calendar = .current
    ) -> Int {
        var cursor = day.adding(days: -1, calendar: calendar)
        while cursor.isWeekend(calendar: calendar) { cursor = cursor.adding(days: -1, calendar: calendar) }
        return ending(at: cursor, history: history, rules: rules, calendar: calendar)
    }

    /// Streak value to report for `today`: if today's goals are met, the streak includes today;
    /// otherwise it is the streak carried in from the most recent completed weekday.
    public static func current(
        today: DayKey,
        history: [DayKey: DaySummary],
        rules: ScoringRules = .standard,
        calendar: Calendar = .current
    ) -> Int {
        if let t = history[today], rules.allGoalsMet(t) {
            return ending(at: today, history: history, rules: rules, calendar: calendar)
        }
        return carried(into: today, history: history, rules: rules, calendar: calendar)
    }
}
