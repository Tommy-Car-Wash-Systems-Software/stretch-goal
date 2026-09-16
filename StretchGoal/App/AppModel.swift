import AppKit
import Foundation
import Observation
import StretchGoalCore
import SwiftUI

@Observable
@MainActor
final class AppModel {
    let prefs = Preferences()
    let notifier = Notifier()
    let sessions = SessionRunner()
    let nudges = NudgePresenter()
    let rules: ScoringRules = .standard
    let deviceId: String
    let memberId: String

    private(set) var day: LocalDay
    /// Past days only; today lives in `day`.
    private(set) var pastDays: [DayKey: DaySummary]
    private(set) var locked = false

    private let store = DayStore()
    private var monitor: ActivityMonitor?

    init() {
        let device = Identity.deviceId()
        let member = Identity.memberId()
        let today = DayKey(.now)
        let store = DayStore()
        deviceId = device
        memberId = member
        day = store.load(today) ?? LocalDay(summary: DaySummary(memberId: member, deviceId: device, date: today))
        pastDays = Dictionary(uniqueKeysWithValues: store.loadRecent(limit: 60, excluding: today).map { ($0.date, $0.summary) })

        sessions.onComplete = { [weak self] kind in self?.complete(kind) }
        sessions.idleSeconds = { ActivityMonitor.idleSeconds() }
        monitor = ActivityMonitor { [weak self] idle, locked in self?.sample(idleSeconds: idle, locked: locked) }
        Task { await notifier.requestAuthorization() }
        #if DEBUG
        observeDebugTriggers()
        #endif
    }

    // MARK: Derived state

    var today: DayKey { day.date }

    var history: [DayKey: DaySummary] {
        var all = pastDays
        all[today] = day.summary
        return all
    }

    var streak: Int { Streak.current(today: today, history: history, rules: rules) }

    var score: DayScore {
        Score.daily(day.summary, streak: Streak.carried(into: today, history: history, rules: rules), rules: rules)
    }

    func sittingSeconds(at now: Date) -> TimeInterval { day.tracker.currentSit(at: now) }

    enum DayStatus { case none, partial, complete, future }

    func weekStatuses() -> [(day: DayKey, status: DayStatus)] {
        Week(containing: today).days.map { d in
            if d > today { return (d, .future) }
            guard let s = history[d] else { return (d, .none) }
            if rules.allGoalsMet(s) { return (d, .complete) }
            return (d, s.breaks + s.waterMl + s.mindful + s.eyeRests + s.steps > 0 ? .partial : .none)
        }
    }

    var recentDays: [DaySummary] {
        history.values.sorted { $0.date > $1.date }
    }

    // MARK: Actions

    /// Short-lived message shown under the water row when a log is refused.
    private(set) var waterNotice: String?
    private var noticeTask: Task<Void, Never>?

    var waterAtLimit: Bool { day.summary.waterMl >= rules.water.capMl }

    @discardableResult
    func logWater(ml: Int) -> ScoringRules.WaterCategory.LogCheck {
        let now = Date.now
        rolloverIfNeeded(now)
        let recent = day.waterMl(within: rules.water.burstWindow, before: now)
        let check = rules.water.check(adding: ml, total: day.waterMl, recentMl: recent)
        switch check {
        case .ok:
            day.waterEntries.append(WaterEntry(ml: ml, at: now))
            commit(now: now)
        case .dailyLimit:
            showNotice(Quips.waterDailyLimit(seed: daySeed))
        case .tooFast:
            showNotice(Quips.waterTooFast(seed: daySeed + day.waterEntries.count))
        }
        return check
    }

    func undoWater() {
        guard !day.waterEntries.isEmpty else { return }
        day.waterEntries.removeLast()
        commit()
    }

    private func showNotice(_ text: String) {
        waterNotice = text
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.waterNotice = nil
        }
    }

    /// Replace today's total, as read off a phone or watch.
    func setSteps(_ total: Int) {
        rolloverIfNeeded(.now)
        day.summary.steps = rules.steps.clamp(total)
        commit()
    }

    /// Add a walk on top of today's total.
    func addSteps(_ count: Int) {
        setSteps(day.summary.steps + count)
    }

    // MARK: Celebrations

    private var daySeed: Int { today.year * 400 + today.month * 31 + today.day }

    private func celebrateIfEarned() {
        let s = day.summary
        if !day.celebratedAllGoals, rules.allGoalsMet(s) {
            day.celebratedAllGoals = true
            nudges.celebrate(title: Quips.allGoalsHit(seed: daySeed), body: Quips.streak(streak), symbol: "trophy.fill", tint: .yellow)
            return
        }
        for milestone in Quips.stepMilestones.reversed() where s.steps >= milestone && !day.celebratedMilestones.contains(milestone) {
            day.celebratedMilestones.append(contentsOf: Quips.stepMilestones.filter { $0 <= milestone })
            let body = milestone == rules.steps.goal ? Quips.stepsGoalHit(seed: daySeed) : "steps on the leaderboard. everything is a competition."
            nudges.celebrate(title: Quips.stepMilestone(milestone, seed: daySeed + milestone), body: body, symbol: "figure.walk.motion", tint: .green)
            return
        }
        if rules.water.goalMet(s.waterMl), !day.celebratedMilestones.contains(-1) {
            day.celebratedMilestones.append(-1)
            nudges.celebrate(title: Quips.waterGoalHit(seed: daySeed), body: "\(s.waterMl.formatted()) ml today.", symbol: "drop.fill", tint: .blue)
            return
        }
        if rules.eyeRests.goalMet(s.eyeRests), !day.celebratedMilestones.contains(-2) {
            day.celebratedMilestones.append(-2)
            nudges.celebrate(title: Quips.eyeGoalHit(seed: daySeed), body: "every 20 minutes, 20 feet, 20 seconds. you're doing it.", symbol: "eye", tint: .orange)
        }
    }

    func start(_ kind: SessionKind) {
        nudges.dismiss()
        sessions.start(GuidedSession.standard(kind))
    }

    /// Fires the configured nudge immediately so the person can see what it looks like.
    func previewNudge() {
        showNudge(sitMinutes: Int(sittingSeconds(at: .now)) / 60)
    }

    private func showNudge(sitMinutes: Int) {
        if prefs.nudgeStyle == .banner {
            notifier.nudge(sitMinutes: sitMinutes)
            return
        }
        nudges.show(sitMinutes: sitMinutes, style: prefs.nudgeStyle) { kind in
            guard let kind, let url = URL(string: "stretchgoal://session/\(kind.rawValue)") else { return }
            NSWorkspace.shared.open(url)
        }
    }

    private func complete(_ kind: SessionKind) {
        rolloverIfNeeded(.now)
        day.completedSessions.append(kind)
        if kind.credit == .breakTaken {
            Tracker.recordMovement(&day.tracker, at: .now)
        }
        commit()
    }

    // MARK: Sampling

    private func sample(idleSeconds: TimeInterval, locked: Bool) {
        let now = Date.now
        self.locked = locked
        rolloverIfNeeded(now)
        let events = Tracker.advance(&day.tracker, now: now, idleSeconds: idleSeconds, locked: locked, config: prefs.trackerConfig)
        if locked { nudges.dismiss() }
        for event in events {
            switch event {
            case let .nudge(sitSeconds):
                showNudge(sitMinutes: sitSeconds / 60)
            case .breakDetected:
                nudges.dismiss()
            }
        }
        commit(now: now)
    }

    private func rolloverIfNeeded(_ now: Date) {
        let key = DayKey(now)
        guard key != day.date else { return }
        day.refreshSummary(now: now)
        store.save(day)
        pastDays[day.date] = day.summary
        day = LocalDay(summary: DaySummary(memberId: memberId, deviceId: deviceId, date: key))
    }

    private func commit(now: Date = .now) {
        day.refreshSummary(now: now)
        celebrateIfEarned()
        store.save(day)
    }

    // MARK: Voice

    func statusLine(at now: Date) -> (headline: String, quip: String) {
        let seed = daySeed + Int(now.timeIntervalSince1970 / 900)
        if locked { return ("Away", Quips.away(seed: seed)) }
        let sit = Int(sittingSeconds(at: now))
        guard sit > 0 else { return ("Not sitting", Quips.notSitting(seed: seed)) }
        return ("Sitting for \(MenuBarView.duration(sit))", Quips.sitting(minutes: sit / 60, seed: seed))
    }

    var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    var storeDirectory: URL { store.directory }

    #if DEBUG
    private var debugObserver: (any NSObjectProtocol)?

    private func observeDebugTriggers() {
        debugObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.tommycarwash.StretchGoal.debug.nudge"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.previewNudge() }
        }
        debugStepsObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.tommycarwash.StretchGoal.debug.steps"), object: nil, queue: .main
        ) { [weak self] note in
            let total = (note.object as? String).flatMap(Int.init) ?? 0
            MainActor.assumeIsolated { self?.setSteps(total) }
        }
    }
    private var debugStepsObserver: (any NSObjectProtocol)?
    #endif
}

enum Identity {
    private static let deviceKey = "identity.deviceId"
    private static let memberKey = "identity.memberId"

    static func deviceId() -> String {
        stored(deviceKey) { String(UUID().uuidString.prefix(8)).lowercased() }
    }

    static func memberId() -> String {
        stored(memberKey) { NSUserName().lowercased() }
    }

    private static func stored(_ key: String, default make: () -> String) -> String {
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let value = make()
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
}
