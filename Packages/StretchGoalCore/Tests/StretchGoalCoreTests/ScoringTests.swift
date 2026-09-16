import Testing
@testable import StretchGoalCore

@Suite struct ScoringTests {
    @Test func basePointsPerCategory() {
        let s = Fixtures.summary("2026-09-16", breaks: 2, water: 3, mindful: 1)
        let score = Score.daily(s, streak: 0)
        #expect(score.base == 2 * 10 + 3 * 3 + 1 * 8)
        #expect(score.bonus == 0)
        #expect(score.total == 37)
        #expect(!score.allGoalsMet)
    }

    @Test func capsStopSpamming() {
        let s = Fixtures.summary("2026-09-16", breaks: 50, water: 500, mindful: 40)
        let score = Score.daily(s, streak: 0)
        #expect(score.base == 8 * 10 + 10 * 3 + 4 * 8)
    }

    @Test func allGoalsBonusAndStreakMultiplier() {
        let s = Fixtures.perfect("2026-09-16")
        let noStreak = Score.daily(s, streak: 0)
        #expect(noStreak.allGoalsMet)
        #expect(noStreak.bonus == 25)
        #expect(noStreak.base == 60 + 24 + 16)
        #expect(noStreak.total == 125)

        let streak3 = Score.daily(s, streak: 3)
        #expect(streak3.multiplierPercent == 115)
        #expect(streak3.total == 125 * 115 / 100)

        let capped = Score.daily(s, streak: 40)
        #expect(capped.multiplierPercent == 150)
    }

    @Test func negativeCountsScoreZero() {
        let s = Fixtures.summary("2026-09-16", breaks: -3)
        #expect(Score.daily(s, streak: 0).base == 0)
    }
}
