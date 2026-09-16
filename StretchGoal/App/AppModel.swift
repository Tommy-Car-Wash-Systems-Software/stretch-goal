import AppKit
import Foundation
import Observation
import StretchGoalCore

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
            return (d, s.breaks + s.waterTaps + s.mindful > 0 ? .partial : .none)
        }
    }

    var recentDays: [DaySummary] {
        history.values.sorted { $0.date > $1.date }
    }

    // MARK: Actions

    func logWater(ml: Int) {
        day.waterEntriesMl.append(ml)
        commit()
    }

    func undoWater() {
        guard !day.waterEntriesMl.isEmpty else { return }
        day.waterEntriesMl.removeLast()
        commit()
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
        store.save(day)
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
            forName: Notification.Name("com.brianp.StretchGoal.debug.nudge"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.previewNudge() }
        }
    }
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
