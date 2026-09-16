import Foundation

public struct ScoringRules: Codable, Hashable, Sendable {
    public struct Category: Codable, Hashable, Sendable {
        public var points: Int
        public var goal: Int
        public var cap: Int

        public init(points: Int, goal: Int, cap: Int) {
            self.points = points
            self.goal = goal
            self.cap = cap
        }

        func score(_ count: Int) -> Int { min(max(count, 0), cap) * points }
        func goalMet(_ count: Int) -> Bool { count >= goal }
    }

    public var breaks: Category
    public var water: Category
    public var mindful: Category
    public var allGoalsBonus: Int
    public var streakStepPercent: Int
    public var streakMaxSteps: Int

    public init(
        breaks: Category = .init(points: 10, goal: 6, cap: 8),
        water: Category = .init(points: 3, goal: 8, cap: 10),
        mindful: Category = .init(points: 8, goal: 2, cap: 4),
        allGoalsBonus: Int = 25,
        streakStepPercent: Int = 5,
        streakMaxSteps: Int = 10
    ) {
        self.breaks = breaks
        self.water = water
        self.mindful = mindful
        self.allGoalsBonus = allGoalsBonus
        self.streakStepPercent = streakStepPercent
        self.streakMaxSteps = streakMaxSteps
    }

    public static let standard = ScoringRules()

    public func allGoalsMet(_ day: DaySummary) -> Bool {
        breaks.goalMet(day.breaks) && water.goalMet(day.waterTaps) && mindful.goalMet(day.mindful)
    }

    /// Multiplier applied to a day's base points, expressed in percent (100 = 1.0x).
    public func multiplierPercent(streak: Int) -> Int {
        100 + min(max(streak, 0), streakMaxSteps) * streakStepPercent
    }
}

public struct DayScore: Hashable, Sendable {
    public let base: Int
    public let bonus: Int
    public let streak: Int
    public let multiplierPercent: Int
    public let allGoalsMet: Bool

    public var total: Int { (base + bonus) * multiplierPercent / 100 }
}

public enum Score {
    /// Scores a single day. `streak` is the streak carried in from preceding weekdays
    /// (see `Streak.carried(into:)`), so it never includes the day being scored.
    public static func daily(_ day: DaySummary, streak: Int, rules: ScoringRules = .standard) -> DayScore {
        let base = rules.breaks.score(day.breaks) + rules.water.score(day.waterTaps) + rules.mindful.score(day.mindful)
        let met = rules.allGoalsMet(day)
        return DayScore(
            base: base,
            bonus: met ? rules.allGoalsBonus : 0,
            streak: streak,
            multiplierPercent: rules.multiplierPercent(streak: streak),
            allGoalsMet: met
        )
    }
}
