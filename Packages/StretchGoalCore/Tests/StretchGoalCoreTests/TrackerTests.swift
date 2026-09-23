import Testing
import Foundation
@testable import StretchGoalCore

@Suite struct TrackerTests {
    let cal = Fixtures.calendar
    let t0 = Date(timeIntervalSince1970: 1_789_570_800)
    let config = TrackerConfig(workHours: nil)

    func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

    /// Drives 10-second samples from `from` to `to` minutes with a constant idle reading.
    @discardableResult
    func run(_ s: inout TrackerState, from: Double, to: Double, idle: TimeInterval = 0, locked: Bool = false) -> [TrackerEvent] {
        var events: [TrackerEvent] = []
        var t = from * 60
        while t <= to * 60 + 0.001 {
            events += Tracker.advance(&s, now: t0.addingTimeInterval(t), idleSeconds: idle, locked: locked, config: config, calendar: cal)
            t += 10
        }
        return events
    }

    @Test func accumulatesActiveTimeAndSitting() {
        var s = TrackerState()
        let events = run(&s, from: 0, to: 5)
        #expect(events.isEmpty)
        #expect(s.activeSeconds == 300)
        #expect(Int(s.currentSit(at: at(5))) == 300)
        #expect(s.longestSitSeconds == 300)
    }

    @Test func idleBeyondThresholdEndsSegmentAndCreditsBreakAfterLongSit() {
        var s = TrackerState()
        run(&s, from: 0, to: 25)
        // Hands off the keyboard at minute 25; idle climbs until the threshold trips at minute 28.
        var events: [TrackerEvent] = []
        for tenths in 1...18 {
            let idle = Double(tenths) * 10
            events += Tracker.advance(&s, now: at(25).addingTimeInterval(idle), idleSeconds: idle, locked: false, config: config, calendar: cal)
        }
        #expect(events == [.breakDetected(sitSeconds: 25 * 60)])
        #expect(s.detectedBreaks == 1)
        #expect(s.sitStart == nil)
        #expect(s.currentSit(at: at(28)) == 0)
        #expect(s.activeSeconds == 25 * 60 + 170)
    }

    @Test func shortSitDoesNotEarnBreak() {
        var s = TrackerState()
        run(&s, from: 0, to: 10)
        let events = Tracker.advance(&s, now: at(13), idleSeconds: 180, locked: false, config: config, calendar: cal)
        #expect(events.isEmpty)
        #expect(s.detectedBreaks == 0)
        #expect(s.longestSitSeconds == 600)
    }

    @Test func lockEndsSegmentImmediately() {
        var s = TrackerState()
        run(&s, from: 0, to: 30)
        let events = Tracker.advance(&s, now: at(30).addingTimeInterval(10), idleSeconds: 2, locked: true, config: config, calendar: cal)
        #expect(events == [.breakDetected(sitSeconds: 1810)])
    }

    @Test func nudgesAfterThresholdAndRepeats() {
        var s = TrackerState()
        let fired = run(&s, from: 0, to: 80).compactMap { e -> Int? in
            if case let .nudge(sit) = e { return sit / 60 }
            return nil
        }
        #expect(fired == [45, 60, 75])
    }

    @Test func movementResetsSitWithoutDetectedBreak() {
        var s = TrackerState()
        run(&s, from: 0, to: 50)
        Tracker.recordMovement(&s, at: at(50))
        #expect(s.sitStart == nil)
        #expect(s.longestSitSeconds == 3000)
        #expect(s.detectedBreaks == 0)
        // Away for the session, then back: no second credit for the same segment.
        let away = run(&s, from: 50.5, to: 53.5, idle: 200)
        #expect(away.isEmpty)
        run(&s, from: 54, to: 55)
        #expect(Int(s.currentSit(at: at(55))) == 60)
    }

    @Test func sleepGapEndsSegmentAtLastSample() {
        var s = TrackerState()
        run(&s, from: 0, to: 30)
        // Lid closed for two hours; first sample after wake shows low idle.
        let events = Tracker.advance(&s, now: at(150), idleSeconds: 1, locked: false, config: config, calendar: cal)
        #expect(events == [.breakDetected(sitSeconds: 1800)])
        #expect(s.activeSeconds == 1800)
        #expect(s.currentSit(at: at(150)) < 2)
    }

    @Test func outsideWorkHoursNothingCounts() {
        var s = TrackerState()
        let hours = TrackerConfig(workHours: WorkHours(startMinute: 7 * 60, endMinute: 18 * 60))
        let late = cal.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 23, minute: 0))!
        for i in 0..<60 {
            _ = Tracker.advance(&s, now: late.addingTimeInterval(Double(i) * 10), idleSeconds: 0, locked: false, config: hours, calendar: cal)
        }
        #expect(s.activeSeconds == 0)
        #expect(s.sitStart == nil)
    }

    @Test func workHoursWindow() {
        let hours = WorkHours(startMinute: 7 * 60, endMinute: 18 * 60)
        #expect(hours.contains(cal.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 7, minute: 0))!, calendar: cal))
        #expect(!hours.contains(cal.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 18, minute: 0))!, calendar: cal))
        #expect(!hours.contains(cal.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 6, minute: 59))!, calendar: cal))
    }
}

@Suite struct GuidedSessionTests {
    @Test func totalsMatchSpec() {
        #expect(GuidedSession.standard(.move).totalSeconds == 180)
        #expect(GuidedSession.standard(.breathe).totalSeconds == 128)
        #expect(GuidedSession.standard(.stretch).totalSeconds == 240)
        #expect(GuidedSession.standard(.eyeRest).totalSeconds == 20)
    }

    @Test func stepLookup() {
        let breathe = GuidedSession.standard(.breathe)
        let first = breathe.step(at: 0)!
        #expect(first.step.title == "Inhale")
        #expect(first.remaining == 4)
        let hold = breathe.step(at: 5)!
        #expect(hold.step.title == "Hold")
        #expect(hold.remaining == 3)
        #expect(breathe.step(at: 128) == nil)
    }

    @Test func credits() {
        #expect(SessionKind.move.credit == .breakTaken)
        #expect(SessionKind.stretch.credit == .breakTaken)
        #expect(SessionKind.breathe.credit == .mindful)
        #expect(SessionKind.eyeRest.credit == .eyeRest)
    }
}

@Suite struct LocalDayTests {
    @Test func summaryDerivesFromLocalFacts() {
        var day = LocalDay(summary: Fixtures.summary("2026-09-16"))
        day.tracker.detectedBreaks = 2
        day.completedSessions = [.move, .breathe, .stretch, .eyeRest, .eyeRest]
        day.waterEntries = [250, 500, 250].map { WaterEntry(ml: $0, at: Date(timeIntervalSince1970: 0)) }
        day.tracker.activeSeconds = 1000
        day.tracker.longestSitSeconds = 900
        day.tracker.sitStart = Date(timeIntervalSince1970: 0)
        day.refreshSummary(now: Date(timeIntervalSince1970: 1500))
        #expect(day.summary.breaks == 4)
        #expect(day.summary.mindful == 1)
        #expect(day.summary.eyeRests == 2)
        #expect(day.summary.waterMl == 1000)
        #expect(day.waterMl == 1000)
        #expect(day.summary.activeSeconds == 1000)
        #expect(day.summary.longestSitSeconds == 1500)
    }
}

@Suite struct FirstActiveTests {
    @Test func firstActivityIsRecordedOnce() {
        var s = TrackerState()
        let t0 = Date(timeIntervalSince1970: 1_789_570_800)
        let cfg = TrackerConfig(workHours: nil)
        _ = Tracker.advance(&s, now: t0, idleSeconds: 500, locked: false, config: cfg, calendar: Fixtures.calendar)
        #expect(s.firstActiveAt == nil)
        _ = Tracker.advance(&s, now: t0.addingTimeInterval(10), idleSeconds: 0, locked: false, config: cfg, calendar: Fixtures.calendar)
        #expect(s.firstActiveAt == t0.addingTimeInterval(10))
        _ = Tracker.advance(&s, now: t0.addingTimeInterval(20), idleSeconds: 0, locked: false, config: cfg, calendar: Fixtures.calendar)
        #expect(s.firstActiveAt == t0.addingTimeInterval(10))
    }

    @Test func legacyLocalDayWithoutReminderFlagDecodes() throws {
        let day = LocalDay(summary: Fixtures.summary("2026-09-16"))
        var json = try JSONSerialization.jsonObject(with: Codec.encode(day)) as! [String: Any]
        json.removeValue(forKey: "stepsReminded")
        var tracker = json["tracker"] as! [String: Any]
        tracker.removeValue(forKey: "firstActiveAt")
        json["tracker"] = tracker
        let decoded = try Codec.decode(LocalDay.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!decoded.stepsReminded)
        #expect(decoded.tracker.firstActiveAt == nil)
    }
}

@Suite struct CallsAndStandingTests {
    let cal = Fixtures.calendar
    let t0 = Date(timeIntervalSince1970: 1_789_570_800)
    let config = TrackerConfig(workHours: nil)
    func at(_ m: Double) -> Date { t0.addingTimeInterval(m * 60) }

    @discardableResult
    func run(_ s: inout TrackerState, from: Double, to: Double, idle: TimeInterval = 0, inCall: Bool = false, standing: Bool = false) -> [TrackerEvent] {
        var events: [TrackerEvent] = []
        var t = from * 60
        while t <= to * 60 + 0.001 {
            events += Tracker.advance(&s, now: t0.addingTimeInterval(t), idleSeconds: idle, locked: false, inCall: inCall, standing: standing, config: config, calendar: cal)
            t += 10
        }
        return events
    }

    @Test func silentCallKeepsTheSitGoingWithNoBreakCredit() {
        var s = TrackerState()
        run(&s, from: 0, to: 10)
        // 30 minutes on a call, hands off the keyboard the whole time.
        let events = run(&s, from: 10, to: 40, idle: 900, inCall: true)
        #expect(events.isEmpty)
        #expect(s.detectedBreaks == 0)
        #expect(Int(s.currentSit(at: at(40))) == 40 * 60)
    }

    @Test func nudgesHoldDuringCallAndFireAfter() {
        var s = TrackerState()
        let during = run(&s, from: 0, to: 60, inCall: true)
        #expect(!during.contains { if case .nudge = $0 { true } else { false } })
        let after = run(&s, from: 60, to: 61)
        #expect(after.contains { if case .nudge = $0 { true } else { false } })
    }

    @Test func standingEndsTheSitWithoutCreditAndHoldsIt() {
        var s = TrackerState()
        run(&s, from: 0, to: 30)
        let events = run(&s, from: 30, to: 50, standing: true)
        #expect(events.isEmpty)
        #expect(s.detectedBreaks == 0)
        #expect(s.sitStart == nil)
        #expect(s.longestSitSeconds == 1800)
        #expect(s.activeSeconds == 50 * 60)
        run(&s, from: 50, to: 55)
        #expect(Int(s.currentSit(at: at(55))) == 5 * 60)
    }
}
