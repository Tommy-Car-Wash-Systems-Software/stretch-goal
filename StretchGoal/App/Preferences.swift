import Foundation
import Observation
import StretchGoalCore

@Observable
@MainActor
final class Preferences {
    private let defaults = UserDefaults.standard

    var nudgeAfterMinutes: Int { didSet { defaults.set(nudgeAfterMinutes, forKey: Key.nudgeAfter) } }
    var nudgeRepeatMinutes: Int { didSet { defaults.set(nudgeRepeatMinutes, forKey: Key.nudgeRepeat) } }
    var workHoursEnabled: Bool { didSet { defaults.set(workHoursEnabled, forKey: Key.workHoursEnabled) } }
    var workStartMinute: Int { didSet { defaults.set(workStartMinute, forKey: Key.workStart) } }
    var workEndMinute: Int { didSet { defaults.set(workEndMinute, forKey: Key.workEnd) } }
    var nickname: String { didSet { defaults.set(nickname, forKey: Key.nickname) } }
    var nudgeStyle: NudgeStyle { didSet { defaults.set(nudgeStyle.rawValue, forKey: Key.nudgeStyle) } }

    init() {
        nudgeAfterMinutes = defaults.object(forKey: Key.nudgeAfter) as? Int ?? 45
        nudgeRepeatMinutes = defaults.object(forKey: Key.nudgeRepeat) as? Int ?? 15
        workHoursEnabled = defaults.object(forKey: Key.workHoursEnabled) as? Bool ?? true
        workStartMinute = defaults.object(forKey: Key.workStart) as? Int ?? 7 * 60
        workEndMinute = defaults.object(forKey: Key.workEnd) as? Int ?? 18 * 60
        nickname = defaults.string(forKey: Key.nickname) ?? NSFullUserName()
        nudgeStyle = defaults.string(forKey: Key.nudgeStyle).flatMap(NudgeStyle.init(rawValue:)) ?? .panel
    }

    var trackerConfig: TrackerConfig {
        TrackerConfig(
            nudgeAfter: TimeInterval(nudgeAfterMinutes * 60),
            nudgeRepeat: TimeInterval(nudgeRepeatMinutes * 60),
            workHours: workHoursEnabled ? WorkHours(startMinute: workStartMinute, endMinute: workEndMinute) : nil
        )
    }

    private enum Key {
        static let nudgeAfter = "prefs.nudgeAfterMinutes"
        static let nudgeRepeat = "prefs.nudgeRepeatMinutes"
        static let workHoursEnabled = "prefs.workHoursEnabled"
        static let workStart = "prefs.workStartMinute"
        static let workEnd = "prefs.workEndMinute"
        static let nickname = "prefs.nickname"
        static let nudgeStyle = "prefs.nudgeStyle"
    }
}
