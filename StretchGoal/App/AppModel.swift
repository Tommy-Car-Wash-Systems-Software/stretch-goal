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
    let sync: SyncService
    let updates: UpdateChecker
    let rules: ScoringRules = .standard
    let deviceId: String
    let memberId: String

    private(set) var day: LocalDay
    /// Past days only; today lives in `day`.
    private(set) var pastDays: [DayKey: DaySummary]
    private(set) var locked = false
    private(set) var inCall = false
    /// Standing-desk mode. Honor system; pauses the sitting timer with no break credit.
    private(set) var standing = false
    private(set) var standingSince: Date?

    private let store = DayStore()
    private var monitor: ActivityMonitor?

    init() {
        let device = Identity.deviceId()
        let member = Identity.memberId()
        let today = DayKey(.now)
        let store = DayStore()
        deviceId = device
        memberId = member
        sync = SyncService(cacheDirectory: store.directory.deletingLastPathComponent())
        updates = UpdateChecker(currentVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")
        day = store.load(today) ?? LocalDay(summary: DaySummary(memberId: member, deviceId: device, date: today))
        pastDays = Dictionary(uniqueKeysWithValues: store.loadRecent(limit: 60, excluding: today).map { ($0.date, $0.summary) })

        sessions.onComplete = { [weak self] kind in self?.complete(kind) }
        sessions.idleSeconds = { ActivityMonitor.idleSeconds() }
        sessions.isLocked = { [weak self] in self?.locked ?? false }
        LoginItem.healIfNeeded()
        sync.start(enabled: prefs.sharingEnabled)
        monitor = ActivityMonitor { [weak self] idle, locked in self?.sample(idleSeconds: idle, locked: locked) }
        if prefs.onboarded {
            Task { await notifier.requestAuthorization() }
        } else {
            Task { try? await Task.sleep(for: .seconds(1)); NSWorkspace.shared.open(URL(string: "stretchgoal://welcome")!) }
        }
        updates.start()
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
            commit(now: now, publishNow: true)
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

    /// Steps can be corrected for today and the two days before. Older days are history.
    static let editableStepDays = 3

    var editableDays: [DayKey] { (0..<Self.editableStepDays).map { today.adding(days: -$0) } }

    func steps(on date: DayKey) -> Int {
        date == today ? day.summary.steps : (pastDays[date]?.steps ?? 0)
    }

    /// Replace a day's total, as read off a phone or watch. Past days republish their file.
    func setSteps(_ total: Int, on date: DayKey) {
        rolloverIfNeeded(.now)
        let clamped = rules.steps.clamp(total)
        if date == today {
            day.summary.steps = clamped
            commit(publishNow: true)
            return
        }
        guard editableDays.contains(date) else { return }
        var past = store.load(date) ?? LocalDay(summary: DaySummary(memberId: memberId, deviceId: deviceId, date: date))
        past.summary.steps = clamped
        past.summary.updatedAt = .now
        store.save(past)
        pastDays[date] = past.summary
        sync.publish(profile: profile, summary: past.summary, force: true)
    }

    func setSteps(_ total: Int) { setSteps(total, on: today) }

    /// Add a walk on top of a day's total.
    func addSteps(_ count: Int, on date: DayKey) {
        setSteps(steps(on: date) + count, on: date)
    }

    func addSteps(_ count: Int) { addSteps(count, on: today) }

    // MARK: Reminders

    private var lastWaterReminderAt: Date = .distantPast

    private func checkReminders(now: Date) {
        guard !locked, !inCall, prefs.trackerConfig.workHours?.contains(now) ?? true, !nudges.isShowing, !sessions.isRunning else { return }

        if prefs.waterReminderEnabled, !waterAtLimit {
            let interval = TimeInterval(prefs.waterReminderMinutes * 60)
            let anchor = day.waterEntries.last?.at ?? day.tracker.firstActiveAt
            if let anchor, now.timeIntervalSince(anchor) >= interval, now.timeIntervalSince(lastWaterReminderAt) >= interval {
                lastWaterReminderAt = now
                let minutes = Int(now.timeIntervalSince(anchor) / 60)
                nudges.showCard(
                    title: Quips.waterReminderTitle(minutes: minutes, seed: daySeed + minutes),
                    body: Quips.waterReminderBody(seed: daySeed + minutes),
                    symbol: "drop.fill", tint: .blue,
                    actions: [
                        .init(title: "250 ml", tint: .blue) { [weak self] in self?.logWater(ml: 250) },
                        .init(title: "500 ml", tint: .blue) { [weak self] in self?.logWater(ml: 500) },
                    ],
                    dismissAfter: .seconds(90)
                )
                return
            }
        }

        if prefs.stepsReminderEnabled, !day.stepsReminded, day.summary.steps == 0 {
            let c = Calendar.current.dateComponents([.hour, .minute], from: now)
            if c.hour! * 60 + c.minute! >= prefs.stepsReminderMinute {
                day.stepsReminded = true
                store.save(day)
                let yesterdayMissing = steps(on: today.adding(days: -1)) == 0 && !today.adding(days: -1).isWeekend()
                nudges.showCard(
                    title: Quips.stepsReminderTitle(seed: daySeed),
                    body: Quips.stepsReminderBody(yesterdayMissing: yesterdayMissing, seed: daySeed),
                    symbol: "shoeprints.fill", tint: .teal,
                    actions: [.init(title: "Log steps", tint: .teal) { NSWorkspace.shared.open(URL(string: "stretchgoal://steps")!) }],
                    dismissAfter: .seconds(120)
                )
            }
        }
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
        commit(publishNow: true)
    }

    // MARK: Standing

    func setStanding(_ value: Bool) {
        standing = value
        standingSince = value ? .now : nil
        if value { nudges.dismiss() }
        sample(idleSeconds: ActivityMonitor.idleSeconds(), locked: locked)
    }

    // MARK: Sampling

    private func sample(idleSeconds: TimeInterval, locked: Bool) {
        let now = Date.now
        self.locked = locked
        inCall = !locked && CallMonitor.microphoneInUse()
        rolloverIfNeeded(now)
        let events = Tracker.advance(&day.tracker, now: now, idleSeconds: idleSeconds, locked: locked,
                                     inCall: inCall, standing: standing, config: prefs.trackerConfig)
        if locked { nudges.dismiss() }
        for event in events {
            switch event {
            case let .nudge(sitSeconds):
                showNudge(sitMinutes: sitSeconds / 60)
            case .breakDetected:
                nudges.dismiss()
            }
        }
        commit(now: now, publishNow: events.contains { if case .breakDetected = $0 { true } else { false } })
        checkReminders(now: now)
        checkWeeklyRecap()
    }

    private func rolloverIfNeeded(_ now: Date) {
        let key = DayKey(now)
        guard key != day.date else { return }
        day.refreshSummary(now: now)
        store.save(day)
        pastDays[day.date] = day.summary
        day = LocalDay(summary: DaySummary(memberId: memberId, deviceId: deviceId, date: key))
    }

    private func commit(now: Date = .now, publishNow: Bool = false) {
        day.refreshSummary(now: now)
        celebrateIfEarned()
        store.save(day)
        sync.publish(profile: profile, summary: day.summary, force: publishNow)
    }

    // MARK: Team

    var profile: MemberProfile {
        MemberProfile(memberId: memberId, nickname: prefs.nickname.trimmingCharacters(in: .whitespaces).isEmpty ? memberId : prefs.nickname)
    }

    func setSharing(_ enabled: Bool) {
        prefs.sharingEnabled = enabled
        if enabled {
            sync.start(enabled: true)
            commit(publishNow: true)
        } else {
            sync.stop()
        }
    }

    func chooseSharedFolder(_ url: URL?) {
        SharedFolderLocator.override = url
        sync.relocate()
        if prefs.sharingEnabled { commit(publishNow: true) }
    }

    /// Everyone's data plus my own live day, so the board is right even before my file syncs back.
    func leaderboard(for week: Week) -> [LeaderboardEntry] {
        var summaries = sync.snapshot.summaries.filter { $0.memberId != memberId || $0.deviceId != deviceId }
        summaries.append(contentsOf: history.values.filter { week.contains($0.date) })
        var profiles = sync.snapshot.profiles.filter { $0.memberId != memberId }
        profiles.append(profile)
        return Leaderboard.compute(week: week, today: today, profiles: profiles, summaries: summaries, rules: rules)
    }

    var myRankLine: String? {
        guard prefs.sharingEnabled else { return nil }
        let board = leaderboard(for: Week(containing: today))
        guard board.count > 1, let me = board.first(where: { $0.memberId == memberId }) else { return nil }
        return "#\(me.rank) of \(board.count) this week"
    }

    // MARK: Weekly recap

    private func checkWeeklyRecap() {
        guard prefs.sharingEnabled, !today.isWeekend(), !nudges.isShowing else { return }
        let week = Week(containing: today)
        guard prefs.recapShownForWeek != week.monday.description else { return }
        let board = leaderboard(for: week.previous)
        guard board.count > 1, let me = board.first(where: { $0.memberId == memberId }) else { return }
        prefs.recapShownForWeek = week.monday.description
        let text = recapText(for: week.previous, board: board)
        nudges.showCard(
            title: Quips.recapTitle(rank: me.rank, count: board.count, seed: daySeed),
            body: "\(me.points) pts · \(me.goalDays) perfect days · \(me.steps.formatted()) steps",
            symbol: me.rank == 1 ? "crown.fill" : "trophy", tint: me.rank == 1 ? .yellow : .orange,
            actions: [
                .init(title: "Copy team recap", tint: .orange) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                },
                .init(title: "Leaderboard", tint: .gray.opacity(0.6)) { NSWorkspace.shared.open(URL(string: "stretchgoal://leaderboard")!) },
            ],
            dismissAfter: .seconds(120)
        )
    }

    /// A pasteable team summary for a week.
    func recapText(for week: Week, board: [LeaderboardEntry]) -> String {
        let medals = ["🥇", "🥈", "🥉"]
        let range = "\(week.monday.date().formatted(.dateTime.month(.abbreviated).day())) – \(week.sunday.date().formatted(.dateTime.month(.abbreviated).day()))"
        var lines = ["Stretch Goal · week of \(range)"]
        for e in board.prefix(5) {
            let medal = e.rank <= 3 ? medals[e.rank - 1] : "#\(e.rank)"
            var bits = ["\(e.points) pts"]
            if e.goalDays > 0 { bits.append("\(e.goalDays) perfect day\(e.goalDays == 1 ? "" : "s")") }
            if e.streak > 0 { bits.append("\(e.streak)-day streak") }
            if e.steps > 0 { bits.append("\(e.steps.formatted()) steps") }
            lines.append("\(medal) \(e.nickname) · \(bits.joined(separator: " · "))")
        }
        if board.count > 5 { lines.append("…and \(board.count - 5) more who also touched grass") }
        lines.append("new week. the chair is undefeated until it isn't. \(Quips.repoURL)")
        return lines.joined(separator: "\n")
    }

    // MARK: Voice

    func statusLine(at now: Date) -> (headline: String, quip: String) {
        let seed = daySeed + Int(now.timeIntervalSince1970 / 900)
        if locked { return ("Away", Quips.away(seed: seed)) }
        if standing, let since = standingSince {
            let m = Int(now.timeIntervalSince(since) / 60)
            return ("Standing for \(MenuBarView.duration(m * 60))", Quips.standing(minutes: m, seed: seed))
        }
        let sit = Int(sittingSeconds(at: now))
        if inCall, sit > 0 { return ("Sitting for \(MenuBarView.duration(sit))", Quips.inCall(seed: seed)) }
        guard sit > 0 else { return ("Not sitting", Quips.notSitting(seed: seed)) }
        return ("Sitting for \(MenuBarView.duration(sit))", Quips.sitting(minutes: sit / 60, seed: seed))
    }

    /// What the menu bar itself shows: the icon changes with state, minutes appear once the
    /// sit is long enough to nag about.
    var menuBarSymbol: String {
        if locked { return "figure.walk" }
        if standing { return "figure.stand" }
        if inCall { return "figure.seated.side" }
        return sittingSeconds(at: .now) >= TimeInterval(prefs.nudgeAfterMinutes * 60) ? "figure.seated.side" : "figure.walk"
    }

    var menuBarText: String? {
        guard !locked, !standing else { return nil }
        let sit = Int(sittingSeconds(at: .now))
        guard sit >= prefs.nudgeAfterMinutes * 60 else { return nil }
        return "\(sit / 60)m"
    }

    // MARK: Sharing removal

    func stopSharingAndRemoveFiles() throws {
        prefs.sharingEnabled = false
        try sync.removeMyFiles(memberId: memberId)
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
    private var debugCardObserver: (any NSObjectProtocol)? = DistributedNotificationCenter.default().addObserver(
        forName: Notification.Name("com.tommycarwash.StretchGoal.debug.sharecard"), object: nil, queue: .main
    ) { note in
        guard let path = note.object as? String else { return }
        MainActor.assumeIsolated { ShareCard.renderSample(points: 382, to: URL(fileURLWithPath: path)) }
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
