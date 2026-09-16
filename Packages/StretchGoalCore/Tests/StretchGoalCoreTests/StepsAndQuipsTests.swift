import Testing
import Foundation
@testable import StretchGoalCore

@Suite struct StepsTests {
    @Test func stepsScorePerThousandWithCap() {
        let rules = ScoringRules.standard
        #expect(Score.daily(Fixtures.summary("2026-09-16"), streak: 0).base == 0)
        var s = Fixtures.summary("2026-09-16"); s.steps = 4999
        #expect(Score.daily(s, streak: 0).base == 8)
        s.steps = 7000
        #expect(Score.daily(s, streak: 0).base == 14)
        #expect(rules.steps.goalMet(7000))
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
        #expect(board[0].points == 10 + 14)
    }

    @Test func v1FilesWithoutStepsStillDecode() throws {
        let legacy = Data("""
        {"schemaVersion":1,"memberId":"x","deviceId":"y","date":"2026-09-16","timeZone":"UTC",
         "breaks":2,"waterTaps":3,"mindful":1,"activeSeconds":10,"longestSitSeconds":5,
         "updatedAt":"2026-09-16T15:42:10Z"}
        """.utf8)
        let decoded = try Codec.decode(DaySummary.self, from: legacy)
        #expect(decoded.steps == 0)
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
        let mile = Quips.stepMilestone(2000, seed: 3) // seed 3 → miles
        #expect(mile.contains("1 actual mile"))
        #expect(!mile.contains("miles"))
    }

    @Test func streakCopy() {
        #expect(Quips.streak(0).contains("no streak"))
        #expect(Quips.streak(7).contains("unhinged"))
        #expect(Quips.streak(12).contains("personality"))
    }
}
