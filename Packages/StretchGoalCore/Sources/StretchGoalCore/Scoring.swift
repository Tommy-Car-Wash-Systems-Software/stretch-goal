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
        public func goalMet(_ count: Int) -> Bool { count >= goal }
    }

    /// Steps score per thousand and never gate the all-goals bonus: not everyone carries a counter.
    public struct StepsCategory: Codable, Hashable, Sendable {
        public var pointsPerThousand: Int
        public var goal: Int
        public var cap: Int
        /// Entries above this are clamped. Roughly 15 miles: anything higher is a typo or a lie.
        public var maxLogged: Int

        public init(pointsPerThousand: Int, goal: Int, cap: Int, maxLogged: Int = 30_000) {
            self.pointsPerThousand = pointsPerThousand
            self.goal = goal
            self.cap = cap
            self.maxLogged = maxLogged
        }

        public func clamp(_ steps: Int) -> Int { min(max(steps, 0), maxLogged) }

        func score(_ steps: Int) -> Int { min(max(steps, 0), cap) / 1000 * pointsPerThousand }
        public func goalMet(_ steps: Int) -> Bool { steps >= goal }
    }

    /// Water scores per 250 ml glass. Goal 2,000 ml is the common "eight glasses" heuristic and
    /// sits inside the 2.0–2.5 L/day from beverages that EFSA and the US IOM describe as adequate.
    public struct WaterCategory: Codable, Hashable, Sendable {
        public var pointsPerGlass: Int
        public var glassMl: Int
        public var goalMl: Int
        /// Logging and scoring both stop here. Equal to the goal: exceeding the recommendation
        /// is not a health target, so the app will not record it.
        public var capMl: Int
        /// Burst limit: at most this much water within `burstWindow` seconds.
        public var burstMl: Int
        public var burstWindow: TimeInterval

        public init(pointsPerGlass: Int, glassMl: Int, goalMl: Int, capMl: Int, burstMl: Int = 750, burstWindow: TimeInterval = 30 * 60) {
            self.pointsPerGlass = pointsPerGlass
            self.glassMl = glassMl
            self.goalMl = goalMl
            self.capMl = capMl
            self.burstMl = burstMl
            self.burstWindow = burstWindow
        }

        public enum LogCheck: Equatable, Sendable { case ok, dailyLimit, tooFast }

        /// Whether another `ml` can be logged given today's total and what was logged in the window.
        public func check(adding ml: Int, total: Int, recentMl: Int) -> LogCheck {
            if total + ml > capMl { return .dailyLimit }
            if recentMl + ml > burstMl { return .tooFast }
            return .ok
        }

        public var goalGlasses: Int { goalMl / glassMl }
        public func glasses(_ ml: Int) -> Int { max(ml, 0) / glassMl }
        func score(_ ml: Int) -> Int { min(max(ml, 0), capMl) / glassMl * pointsPerGlass }
        public func goalMet(_ ml: Int) -> Bool { ml >= goalMl }
    }

    public var breaks: Category
    public var water: WaterCategory
    public var mindful: Category
    /// 20-20-20 eye rests. Cheap points, high cap, not part of the all-goals bonus.
    public var eyeRests: Category
    public var steps: StepsCategory
    public var allGoalsBonus: Int
    public var streakStepPercent: Int
    public var streakMaxSteps: Int

    public init(
        breaks: Category = .init(points: 10, goal: 8, cap: 12),
        water: WaterCategory = .init(pointsPerGlass: 3, glassMl: 250, goalMl: 2000, capMl: 2000),
        mindful: Category = .init(points: 8, goal: 2, cap: 4),
        eyeRests: Category = .init(points: 2, goal: 4, cap: 12),
        steps: StepsCategory = .init(pointsPerThousand: 2, goal: 8000, cap: 15000),
        allGoalsBonus: Int = 25,
        streakStepPercent: Int = 5,
        streakMaxSteps: Int = 10
    ) {
        self.breaks = breaks
        self.water = water
        self.mindful = mindful
        self.eyeRests = eyeRests
        self.steps = steps
        self.allGoalsBonus = allGoalsBonus
        self.streakStepPercent = streakStepPercent
        self.streakMaxSteps = streakMaxSteps
    }

    public static let standard = ScoringRules()

    /// The three desk goals. Steps and eye rests are deliberately excluded.
    public func allGoalsMet(_ day: DaySummary) -> Bool {
        breaks.goalMet(day.breaks) && water.goalMet(day.waterMl) && mindful.goalMet(day.mindful)
    }

    /// Multiplier applied to a day's base points, expressed in percent (100 = 1.0x).
    public func multiplierPercent(streak: Int) -> Int {
        100 + min(max(streak, 0), streakMaxSteps) * streakStepPercent
    }
}

public struct DayScore: Hashable, Sendable {
    public struct Part: Hashable, Sendable, Identifiable {
        public let name: String
        public let points: Int
        public var id: String { name }
    }

    public let parts: [Part]
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
        let parts = [
            DayScore.Part(name: "Breaks", points: rules.breaks.score(day.breaks)),
            DayScore.Part(name: "Water", points: rules.water.score(day.waterMl)),
            DayScore.Part(name: "Mindful", points: rules.mindful.score(day.mindful)),
            DayScore.Part(name: "Eye rests", points: rules.eyeRests.score(day.eyeRests)),
            DayScore.Part(name: "Steps", points: rules.steps.score(day.steps)),
        ]
        let base = parts.reduce(0) { $0 + $1.points }
        let met = rules.allGoalsMet(day)
        return DayScore(
            parts: parts,
            base: base,
            bonus: met ? rules.allGoalsBonus : 0,
            streak: streak,
            multiplierPercent: rules.multiplierPercent(streak: streak),
            allGoalsMet: met
        )
    }
}
