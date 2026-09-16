import Foundation

public struct LeaderboardEntry: Hashable, Sendable, Identifiable {
    public var id: String { memberId }
    public let memberId: String
    public let nickname: String
    public let rank: Int
    public let points: Int
    public let streak: Int
    public let goalDays: Int
    public let goalsMetToday: Bool
}

public enum Leaderboard {
    /// Computes the weekly leaderboard from raw summaries. Any number of devices per member is fine.
    /// Points and streaks are derived here, never read from files.
    public static func compute(
        week: Week,
        today: DayKey,
        profiles: [MemberProfile],
        summaries: [DaySummary],
        rules: ScoringRules = .standard,
        calendar: Calendar = .current
    ) -> [LeaderboardEntry] {
        let byMember = Dictionary(grouping: summaries.filter { $0.schemaVersion == DaySummary.currentSchemaVersion }, by: \.memberId)
        let nicknames = Dictionary(profiles.map { ($0.memberId, $0.nickname) }, uniquingKeysWith: { a, _ in a })

        var entries: [LeaderboardEntry] = byMember.map { memberId, raw in
            let history: [DayKey: DaySummary] = Dictionary(grouping: raw, by: \.date)
                .compactMapValues { DaySummary.merge($0) }

            var points = 0
            var goalDays = 0
            for day in week.days where day <= today {
                guard let summary = history[day] else { continue }
                let streak = Streak.carried(into: day, history: history, rules: rules, calendar: calendar)
                let score = Score.daily(summary, streak: streak, rules: rules)
                points += score.total
                if score.allGoalsMet { goalDays += 1 }
            }

            return LeaderboardEntry(
                memberId: memberId,
                nickname: nicknames[memberId] ?? memberId,
                rank: 0,
                points: points,
                streak: Streak.current(today: today, history: history, rules: rules, calendar: calendar),
                goalDays: goalDays,
                goalsMetToday: history[today].map(rules.allGoalsMet) ?? false
            )
        }

        entries.sort {
            if $0.points != $1.points { return $0.points > $1.points }
            if $0.streak != $1.streak { return $0.streak > $1.streak }
            if $0.goalDays != $1.goalDays { return $0.goalDays > $1.goalDays }
            return $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending
        }

        return entries.enumerated().map { index, e in
            LeaderboardEntry(memberId: e.memberId, nickname: e.nickname, rank: index + 1, points: e.points,
                             streak: e.streak, goalDays: e.goalDays, goalsMetToday: e.goalsMetToday)
        }
    }
}
