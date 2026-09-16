import Testing
import Foundation
@testable import StretchGoalCore

@Suite struct MergeTests {
    @Test func takesMaxPerCountAcrossDevices() {
        let a = Fixtures.summary("2026-09-16", device: "laptop", breaks: 3, water: 5, mindful: 0,
                                 updatedAt: Date(timeIntervalSince1970: 100))
        let b = Fixtures.summary("2026-09-16", device: "desktop", breaks: 1, water: 7, mindful: 2,
                                 updatedAt: Date(timeIntervalSince1970: 200))
        let m = DaySummary.merge([a, b])!
        #expect(m.breaks == 3)
        #expect(m.waterMl == 1750)
        #expect(m.mindful == 2)
        #expect(m.deviceId == "desktop")
        #expect(m.updatedAt == Date(timeIntervalSince1970: 200))
    }

    @Test func emptyMergeIsNil() {
        #expect(DaySummary.merge([]) == nil)
    }
}

@Suite struct LeaderboardTests {
    let cal = Fixtures.calendar
    let today = Fixtures.day("2026-09-16")
    var week: Week { Week(containing: today, calendar: cal) }

    @Test func ranksByPointsThenStreakThenGoalDays() {
        let profiles = [
            MemberProfile(memberId: "a", nickname: "Ada"),
            MemberProfile(memberId: "b", nickname: "Bo"),
            MemberProfile(memberId: "c", nickname: "Cy"),
        ]
        let summaries = [
            Fixtures.perfect("2026-09-14", member: "a"), Fixtures.perfect("2026-09-15", member: "a"), Fixtures.perfect("2026-09-16", member: "a"),
            Fixtures.summary("2026-09-16", member: "b", breaks: 12, water: 8, mindful: 4),
            Fixtures.summary("2026-09-16", member: "c", breaks: 1),
        ]
        let board = Leaderboard.compute(week: week, today: today, profiles: profiles, summaries: summaries, calendar: cal)
        #expect(board.map(\.nickname) == ["Ada", "Bo", "Cy"])
        #expect(board.map(\.rank) == [1, 2, 3])
        // Ada: 145 + 145*1.05 + 145*1.10 = 145 + 152 + 159
        #expect(board[0].points == 145 + 152 + 159)
        #expect(board[0].streak == 3)
        #expect(board[0].goalDays == 3)
        #expect(board[0].goalsMetToday)
        #expect(board[1].points == 120 + 24 + 32 + 25)
        #expect(board[2].points == 10)
        #expect(!board[2].goalsMetToday)
    }

    @Test func ignoresDaysOutsideWeekAndInFuture() {
        let summaries = [
            Fixtures.perfect("2026-09-11", member: "a"),
            Fixtures.perfect("2026-09-17", member: "a"),
            Fixtures.summary("2026-09-16", member: "a", breaks: 1),
        ]
        let board = Leaderboard.compute(week: week, today: today, profiles: [], summaries: summaries, calendar: cal)
        #expect(board.count == 1)
        #expect(board[0].points == 10)
        #expect(board[0].nickname == "a")
    }

    @Test func mergesDevicesBeforeScoring() {
        let summaries = [
            Fixtures.summary("2026-09-16", member: "a", device: "x", breaks: 8),
            Fixtures.summary("2026-09-16", member: "a", device: "y", water: 8, mindful: 2),
        ]
        let board = Leaderboard.compute(week: week, today: today, profiles: [], summaries: summaries, calendar: cal)
        #expect(board[0].points == 145)
        #expect(board[0].goalsMetToday)
    }

    @Test func skipsUnknownSchemaVersions() {
        var future = Fixtures.perfect("2026-09-16", member: "a")
        future.schemaVersion = 99
        let board = Leaderboard.compute(week: week, today: today, profiles: [], summaries: [future], calendar: cal)
        #expect(board.isEmpty)
    }
}
