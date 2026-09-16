import Foundation
import Observation
import StretchGoalCore

@Observable
@MainActor
final class AppModel {
    private(set) var today: DayKey = DayKey(.now)
    private(set) var summary: DaySummary
    var rules: ScoringRules = .standard

    let deviceId: String
    let memberId: String

    init() {
        let day = DayKey(.now)
        let device = Identity.deviceId()
        let member = Identity.memberId()
        today = day
        deviceId = device
        memberId = member
        summary = DaySummary(memberId: member, deviceId: device, date: day)
    }

    var score: DayScore {
        Score.daily(summary, streak: 0, rules: rules)
    }

    var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }
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
