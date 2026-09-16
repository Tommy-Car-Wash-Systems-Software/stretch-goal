import Testing
import Foundation
@testable import StretchGoalCore

@Suite struct DayKeyTests {
    let cal = Fixtures.calendar

    @Test func parsesAndFormats() {
        let key = DayKey(string: "2026-09-16")
        #expect(key == DayKey(year: 2026, month: 9, day: 16))
        #expect(key?.description == "2026-09-16")
        #expect(DayKey(string: "2026-13-01") == nil)
        #expect(DayKey(string: "nope") == nil)
    }

    @Test func ordersChronologically() {
        #expect(Fixtures.day("2026-09-16") < Fixtures.day("2026-10-01"))
        #expect(Fixtures.day("2025-12-31") < Fixtures.day("2026-01-01"))
    }

    @Test func addsDaysAcrossMonthBoundary() {
        #expect(Fixtures.day("2026-09-30").adding(days: 1, calendar: cal) == Fixtures.day("2026-10-01"))
        #expect(Fixtures.day("2026-03-01").adding(days: -1, calendar: cal) == Fixtures.day("2026-02-28"))
    }

    @Test func detectsWeekends() {
        #expect(Fixtures.day("2026-09-12").isWeekend(calendar: cal))
        #expect(Fixtures.day("2026-09-13").isWeekend(calendar: cal))
        #expect(!Fixtures.day("2026-09-14").isWeekend(calendar: cal))
    }

    @Test func weekStartsMonday() {
        let wednesday = Fixtures.day("2026-09-16")
        let week = Week(containing: wednesday, calendar: cal)
        #expect(week.monday == Fixtures.day("2026-09-14"))
        #expect(week.sunday == Fixtures.day("2026-09-20"))
        #expect(week.days.count == 7)
        #expect(Week(containing: Fixtures.day("2026-09-20"), calendar: cal).monday == Fixtures.day("2026-09-14"))
        #expect(Week(containing: Fixtures.day("2026-09-14"), calendar: cal).monday == Fixtures.day("2026-09-14"))
        #expect(week.previous.monday == Fixtures.day("2026-09-07"))
    }
}
