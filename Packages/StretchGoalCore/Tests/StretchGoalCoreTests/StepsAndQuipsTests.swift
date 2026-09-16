import Testing
import Foundation
@testable import StretchGoalCore

@Suite struct StepsTests {
    @Test func stepsScorePerThousandWithCap() {
        let rules = ScoringRules.standard
        #expect(Score.daily(Fixtures.summary("2026-09-16"), streak: 0).base == 0)
        var s = Fixtures.summary("2026-09-16"); s.steps = 4999
        #expect(Score.daily(s, streak: 0).base == 8)
        s.steps = 8000
        #expect(Score.daily(s, streak: 0).base == 16)
        #expect(rules.steps.goalMet(8000))
        #expect(!rules.steps.goalMet(7999))
        s.steps = 40_000
        #expect(Score.daily(s, streak: 0).base == 30)
    }

    @Test func stepsDoNotGateAllGoals() {
        let perfect = Fixtures.perfect("2026-09-16")
        #expect(perfect.steps == 0)
        #expect(ScoringRules.standard.allGoalsMet(perfect))
    }

    @Test func mergeTakesMaxSteps() {
        var a = Fixtures.summary("2026-09-16", device: "a"); a.steps = 3000
        var b = Fixtures.summary("2026-09-16", device: "b"); b.steps = 8000
        #expect(DaySummary.merge([a, b])?.steps == 8000)
    }

    @Test func leaderboardSumsWeeklySteps() {
        var m = Fixtures.summary("2026-09-14", member: "a"); m.steps = 5000
        var t = Fixtures.summary("2026-09-16", member: "a"); t.steps = 7000
        let cal = Fixtures.calendar
        let board = Leaderboard.compute(week: Week(containing: Fixtures.day("2026-09-16"), calendar: cal), today: Fixtures.day("2026-09-16"),
                                        profiles: [], summaries: [m, t], calendar: cal)
        #expect(board[0].steps == 12000)
        #expect(board[0].points == 10 + 14)  // 5k → 10, 7k → 14
    }

    @Test func v1FilesWithoutStepsStillDecode() throws {
        let legacy = Data("""
        {"schemaVersion":1,"memberId":"x","deviceId":"y","date":"2026-09-16","timeZone":"UTC",
         "breaks":2,"waterTaps":3,"mindful":1,"activeSeconds":10,"longestSitSeconds":5,
         "updatedAt":"2026-09-16T15:42:10Z"}
        """.utf8)
        let decoded = try Codec.decode(DaySummary.self, from: legacy)
        #expect(decoded.steps == 0)
        #expect(decoded.eyeRests == 0)
        #expect(decoded.waterMl == 750)  // 3 legacy taps × 250 ml
        #expect(decoded.breaks == 2)
    }

    @Test func legacyLocalDayDecodes() throws {
        let day = LocalDay(summary: Fixtures.summary("2026-09-16"))
        var json = try JSONSerialization.jsonObject(with: Codec.encode(day)) as! [String: Any]
        json.removeValue(forKey: "celebratedMilestones")
        json.removeValue(forKey: "celebratedAllGoals")
        let decoded = try Codec.decode(LocalDay.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.celebratedMilestones.isEmpty)
        #expect(!decoded.celebratedAllGoals)
    }
}

@Suite struct QuipsTests {
    @Test func pickIsDeterministicAndCoversPool() {
        let pool = ["a", "b", "c", "d", "e"]
        #expect(Quips.pick(pool, seed: 42) == Quips.pick(pool, seed: 42))
        let seen = Set((0..<200).map { Quips.pick(pool, seed: $0) })
        #expect(seen.count == pool.count)
    }

    @Test func sittingLinesEscalate() {
        #expect(Quips.sitting(minutes: 5, seed: 1).contains("fresh") || Quips.sitting(minutes: 5, seed: 1).contains("main character") || Quips.sitting(minutes: 5, seed: 1).contains("early-shift"))
        #expect(Quips.sitting(minutes: 200, seed: 1).count > 10)
    }

    @Test func milestoneMathUsesUnits() {
        let line = Quips.stepMilestone(10000, seed: 0) // seed 0 → first unit, 40 steps each
        #expect(line.contains("250 desk-to-Keurig runs"))
        let mile = Quips.stepMilestone(2500, seed: 3) // seed 3 → miles, 2,100 steps each
        #expect(mile.contains("1 actual mile"))
        #expect(!mile.contains("miles"))
    }

    @Test func streakCopy() {
        #expect(Quips.streak(0).contains("no streak"))
        #expect(Quips.streak(7).contains("unhinged"))
        #expect(Quips.streak(12).contains("personality"))
    }
}

@Suite struct RealWorldRulesTests {
    let rules = ScoringRules.standard

    @Test func waterScoresByVolumeNotTaps() {
        var a = Fixtures.summary("2026-09-16"); a.waterMl = 500
        var b = Fixtures.summary("2026-09-16"); b.waterMl = 250 + 250
        #expect(Score.daily(a, streak: 0).base == Score.daily(b, streak: 0).base)
        #expect(Score.daily(a, streak: 0).base == 6)
        #expect(rules.water.glasses(500) == 2)
        #expect(rules.water.goalGlasses == 8)
        #expect(rules.water.goalMet(2000))
        #expect(!rules.water.goalMet(1999))
        var c = Fixtures.summary("2026-09-16"); c.waterMl = 10_000
        #expect(Score.daily(c, streak: 0).base == 12 * 3)
    }

    @Test func eyeRestsScoreSeparatelyAndDoNotGateAllGoals() {
        var s = Fixtures.perfect("2026-09-16")
        #expect(rules.allGoalsMet(s))
        s.eyeRests = 4
        #expect(Score.daily(s, streak: 0).base == 80 + 24 + 16 + 8)
        s.eyeRests = 50
        #expect(Score.daily(s, streak: 0).base == 80 + 24 + 16 + 24)
    }

    @Test func hourlyBreaksIsTheGoal() {
        #expect(rules.breaks.goal == 8)
        #expect(rules.breaks.cap == 12)
    }
}
