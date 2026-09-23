import Foundation

/// The app's voice, courtesy of issue #1. Pools are picked deterministically from a seed so a
/// line stays put while a view re-renders, and rotates when the seed (minute bucket, count,
/// day) changes. Keep it workplace-safe; keep it unhinged.
public enum Quips {
    public static func pick(_ pool: [String], seed: Int) -> String {
        precondition(!pool.isEmpty)
        var h = UInt64(truncatingIfNeeded: seed) &* 0x9E37_79B9_7F4A_7C15
        h ^= h >> 31
        return pool[Int(h % UInt64(pool.count))]
    }

    // MARK: Sitting status (menu bar header)

    public static func sitting(minutes: Int, seed: Int) -> String {
        let pool: [String]
        switch minutes {
        case ..<20: pool = ["fresh. hydrated. unbothered.", "main character posture. for now.", "we love an early-shift queen/king. keep it."]
        case ..<45: pool = ["lowkey settling in. watch it.", "this is fine. this is still fine.", "the chair is getting comfortable. suspicious."]
        case ..<90: pool = ["desk-rotting era has begun.", "bestie. stand. up.", "NPC behavior detected. respawn outside."]
        default: pool = ["villain origin story loading…", "the chair has legally adopted you.", "at this point just touch grass. any grass."]
        }
        return pick(pool, seed: seed)
    }

    public static func notSitting(seed: Int) -> String {
        pick(["not sitting. iconic.", "up and about. as you should.", "standing. we stan."], seed: seed)
    }

    public static func standing(minutes: Int, seed: Int) -> String {
        pick(["standing for \(minutes)m. upright royalty.", "\(minutes) min on your feet. the chair is jealous.", "vertical era. \(minutes) minutes."], seed: seed)
    }

    public static func inCall(seed: Int) -> String {
        pick(["on a call. sitting still counts as sitting, sorry.", "in a meeting. nudges are holding. the chair is not.", "mic's hot. we'll nag you after."], seed: seed)
    }

    public static func recapTitle(rank: Int, count: Int, seed: Int) -> String {
        switch rank {
        case 1: return pick(["last week: #1 of \(count). crown fits.", "you won last week. be normal about it.", "#1 of \(count). the leaderboard is yours, for now."], seed: seed)
        case 2...3: return pick(["last week: #\(rank) of \(count). podium. respectable.", "#\(rank) of \(count) last week. so close it hurts."], seed: seed)
        default: return pick(["last week: #\(rank) of \(count). new week, new you.", "#\(rank) of \(count). the chair won last week. rematch."], seed: seed)
        }
    }

    public static func away(seed: Int) -> String {
        pick(["away. touching grass, presumably.", "screen locked. mysterious.", "gone. the leaderboard remembers."], seed: seed)
    }

    // MARK: Nudges

    public static func nudgeTitle(minutes: Int, seed: Int) -> String {
        pick([
            "bestie it's been \(minutes) min",
            "\(minutes) minutes of desk rot",
            "sitting for \(minutes) min. this is your villain origin story.",
            "\(minutes) min. the chair is winning.",
            "hi. \(minutes) minutes. we need to talk.",
        ], seed: seed)
    }

    public static func nudgeBody(seed: Int) -> String {
        pick([
            "Stand up. Your streak is watching.",
            "Touch grass. Literally. It's right outside.",
            "Peer pressure ate and left no crumbs. Get up.",
            "Somebody on the leaderboard is bodying you right now.",
            "Your spine filed a complaint. Please respond.",
            "Get up so you can sit back down with the moral high ground.",
        ], seed: seed)
    }

    public static func snooze(seed: Int) -> String {
        pick(["Snooze (coward)", "Snooze 15", "not now bestie"], seed: seed)
    }

    // MARK: Sessions

    public static func sessionDone(_ kind: SessionKind, seed: Int) -> String {
        let pool: [String] = switch kind {
        case .move: ["Walk complete. You touched grass. Iconic.", "Moved. Slay. Sitting timer reset.", "3 minutes of not desk-rotting. Ate."]
        case .stretch: ["Stretched. Your hamstrings said thank you.", "Full desk stretch. Understood the assignment.", "Flexibility arc unlocked."]
        case .breathe: ["Breathed on purpose. Main character behavior.", "Box breathing done. Zero thoughts, head empty, in a good way.", "Regulated. Unbothered. Moisturized."]
        case .eyeRest: ["Eyes rested. The Jira board can wait.", "20 seconds of looking at literally anything else. Slay.", "Eye rest logged. Vision: restored. Tickets: still there."]
        }
        return pick(pool, seed: seed)
    }

    public static let sessionPickerTitle = "touch grass"
    public static let sessionPickerSubtitle = "pick your break. all of them count. only finished ones score."

    // MARK: Water

    public static func waterGoalHit(seed: Int) -> String {
        pick(["2 litres. Hydrated royalty.", "Water goal hit. Moisturized. Unbothered. In your lane.", "Hydrate or diedrate. You chose hydrate. Slay."], seed: seed)
    }

    public static func waterDailyLimit(seed: Int) -> String {
        pick(["2 litres logged. that's the recommendation. more isn't healthier, bestie.", "you're at 2 L. hydration: complete. kidneys: thriving. stop.", "daily water done. the rest is just a hobby."], seed: seed)
    }

    public static func waterTooFast(seed: Int) -> String {
        pick(["slow down. that's not how kidneys work.", "750 ml per half hour, max. hydration isn't a speedrun.", "we love the enthusiasm. the leaderboard does not accept chugging."], seed: seed)
    }

    public static func sessionFailed(_ kind: SessionKind, seed: Int) -> String {
        let pool: [String] = switch kind {
        case .move: ["you're still typing. that's not a walk.", "hands on the keyboard the whole time. the walk didn't happen. no credit."]
        case .stretch: ["stretching doesn't involve this much typing. try again.", "the keyboard was very involved in that stretch. no credit."]
        case .breathe: ["breathing and replying to Teams at the same time doesn't count.", "hands off the keyboard. that's the whole exercise."]
        case .eyeRest: ["you looked at the screen. that's the one thing.", "20 feet away means not the monitor. no credit."]
        }
        return pick(pool, seed: seed)
    }

    public static func eyeGoalHit(seed: Int) -> String {
        pick(["4 eye rests. 20-20-20 understood the assignment.", "Eyes rested 4 times. Screen: humbled.", "Eye goal hit. Vision: main character."], seed: seed)
    }

    // MARK: Reminders

    public static func waterReminderTitle(minutes: Int, seed: Int) -> String {
        pick(["hydration check. \(minutes) min, zero water.", "your water bottle called. it's lonely.", "\(minutes) minutes dry. that's a desert, bestie.", "the coffee doesn't count if you didn't log it. drink water."], seed: seed)
    }

    public static func waterReminderBody(seed: Int) -> String {
        pick(["one glass. that's the whole ask.", "hydrate or diedrate.", "your kidneys are typing…", "moisturized. unbothered. that could be you."], seed: seed)
    }

    public static func stepsReminderTitle(seed: Int) -> String {
        pick(["steps check. what's the number?", "phone. health app. number. here.", "the leaderboard has no idea how far you walked."], seed: seed)
    }

    public static func stepsReminderBody(yesterdayMissing: Bool, seed: Int) -> String {
        yesterdayMissing
            ? pick(["and yesterday's are blank. you can still fix that.", "yesterday says zero. we both know that's a lie. fix it."], seed: seed)
            : pick(["log today's total and go home.", "it takes five seconds. the Keurig math awaits."], seed: seed)
    }

    // MARK: Goals & streaks

    public static func allGoalsHit(seed: Int) -> String {
        pick(["All three goals. No crumbs left.", "Breaks, water, mindful. Ate. Left nothing.", "Perfect day. The leaderboard trembles."], seed: seed)
    }

    public static func streak(_ days: Int) -> String {
        switch days {
        case 0: return "no streak yet. today's the day, bestie."
        case 1: return "1 day streak. it begins."
        case 2...4: return "\(days) day streak. locked in."
        case 5...9: return "\(days) day streak. unhinged. keep going."
        default: return "\(days) day streak. this is your whole personality now."
        }
    }

    public static let historyEmpty = "no history yet. every legend has a day one."

    // MARK: Share card

    public static func shareCaption(points: Int, allGoals: Bool, seed: Int) -> String {
        let pool: [String] = allGoals
            ? ["perfect day. no crumbs. cope.", "closed every ring. the chair lost.", "all goals hit. this is what peer pressure looks like."]
            : points == 0
                ? ["day one energy. it goes up from here.", "zero points, infinite potential.", "the streak starts tomorrow. probably."]
                : ["\(points) points of not desk-rotting.", "touched grass. have receipts.", "the leaderboard has been notified."]
        return pick(pool, seed: seed)
    }

    public static let repoURL = "https://github.com/Tommy-Car-Wash-Systems-Software/stretch-goal"
    public static let installHint = "brew tap tommy-car-wash-systems-software/tap && brew install --cask stretch-goal"

    // MARK: Steps

    /// Absurd unit conversions, per issue #1. Steps per unit are rough on purpose.
    public struct Unit: Sendable {
        public let stepsEach: Int
        public let singular: String
        public let plural: String
    }

    public static let units: [Unit] = [
        Unit(stepsEach: 40, singular: "desk-to-Keurig run", plural: "desk-to-Keurig runs"),
        Unit(stepsEach: 110, singular: "lap of the wash tunnel", plural: "laps of the wash tunnel"),
        Unit(stepsEach: 260, singular: "trip to the far bathroom you never use", plural: "trips to the far bathroom you never use"),
        Unit(stepsEach: 2100, singular: "actual mile", plural: "actual miles"),
        Unit(stepsEach: 700, singular: "parking-lot crossing when you parked far to feel something", plural: "parking-lot crossings when you parked far to feel something"),
    ]

    public static let stepMilestones: [Int] = [2500, 5000, 7500, 10000, 12500, 15000, 20000]

    public static func stepMilestone(_ steps: Int, seed: Int) -> String {
        let unit = units[Int(UInt64(truncatingIfNeeded: seed) % UInt64(units.count))]
        let count = steps / unit.stepsEach
        let equivalence = "\(count) \(count == 1 ? unit.singular : unit.plural)"
        let openers = [
            "\(steps.formatted()) steps. that's \(equivalence). slay.",
            "congrats, you walked \(equivalence). the Keurig fears you.",
            "\(steps.formatted()) steps = \(equivalence). peer pressure works.",
            "\(equivalence) today. lowkey athletic.",
        ]
        return pick(openers, seed: seed)
    }

    public static func stepsGoalHit(seed: Int) -> String {
        pick(["Step goal hit. Chronically optimized.", "8,000 steps. Bodying the leaderboard.", "Steps: done. Desk-rot: cancelled."], seed: seed)
    }
}
