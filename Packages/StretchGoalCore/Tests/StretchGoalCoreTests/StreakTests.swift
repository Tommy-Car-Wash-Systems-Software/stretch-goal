import Testing
@testable import StretchGoalCore

@Suite struct StreakTests {
    let cal = Fixtures.calendar

    @Test func countsConsecutiveWeekdays() {
        let h = Fixtures.history([
            Fixtures.perfect("2026-09-14"), Fixtures.perfect("2026-09-15"), Fixtures.perfect("2026-09-16"),
        ])
        #expect(Streak.ending(at: Fixtures.day("2026-09-16"), history: h, calendar: cal) == 3)
    }

    @Test func skipsWeekendsWithoutBreaking() {
        let h = Fixtures.history([
            Fixtures.perfect("2026-09-10"), Fixtures.perfect("2026-09-11"), // Thu, Fri
            Fixtures.perfect("2026-09-14"),                                  // Mon
        ])
        #expect(Streak.ending(at: Fixtures.day("2026-09-14"), history: h, calendar: cal) == 3)
    }

    @Test func weekendActivityDoesNotExtend() {
        let h = Fixtures.history([
            Fixtures.perfect("2026-09-11"), Fixtures.perfect("2026-09-12"), Fixtures.perfect("2026-09-13"),
            Fixtures.perfect("2026-09-14"),
        ])
        #expect(Streak.ending(at: Fixtures.day("2026-09-14"), history: h, calendar: cal) == 2)
    }

    @Test func missedWeekdayBreaksStreak() {
        let h = Fixtures.history([
            Fixtures.perfect("2026-09-14"),
            Fixtures.summary("2026-09-15", breaks: 1),
            Fixtures.perfect("2026-09-16"),
        ])
        #expect(Streak.ending(at: Fixtures.day("2026-09-16"), history: h, calendar: cal) == 1)
    }

    @Test func missingDayBreaksStreak() {
        let h = Fixtures.history([Fixtures.perfect("2026-09-14"), Fixtures.perfect("2026-09-16")])
        #expect(Streak.ending(at: Fixtures.day("2026-09-16"), history: h, calendar: cal) == 1)
    }

    @Test func currentCarriesInWhileTodayIncomplete() {
        let h = Fixtures.history([
            Fixtures.perfect("2026-09-14"), Fixtures.perfect("2026-09-15"),
            Fixtures.summary("2026-09-16", breaks: 2),
        ])
        #expect(Streak.current(today: Fixtures.day("2026-09-16"), history: h, calendar: cal) == 2)
        #expect(Streak.ending(at: Fixtures.day("2026-09-16"), history: h, calendar: cal) == 0)
    }

    @Test func currentOnMondayLooksBackToFriday() {
        let h = Fixtures.history([Fixtures.perfect("2026-09-11")])
        #expect(Streak.current(today: Fixtures.day("2026-09-14"), history: h, calendar: cal) == 1)
    }
}

@Suite struct CarriedStreakTests {
    let cal = Fixtures.calendar

    @Test func lonePerfectDayCarriesZero() {
        let h = Fixtures.history([Fixtures.perfect("2026-09-16")])
        #expect(Streak.carried(into: Fixtures.day("2026-09-16"), history: h, calendar: cal) == 0)
    }

    @Test func thirdDayOfRunCarriesTwo() {
        let h = Fixtures.history([Fixtures.perfect("2026-09-14"), Fixtures.perfect("2026-09-15"), Fixtures.perfect("2026-09-16")])
        #expect(Streak.carried(into: Fixtures.day("2026-09-16"), history: h, calendar: cal) == 2)
    }

    @Test func mondayCarriesFromFriday() {
        let h = Fixtures.history([Fixtures.perfect("2026-09-10"), Fixtures.perfect("2026-09-11")])
        #expect(Streak.carried(into: Fixtures.day("2026-09-14"), history: h, calendar: cal) == 2)
    }
}
