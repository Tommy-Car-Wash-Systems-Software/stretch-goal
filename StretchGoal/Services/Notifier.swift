import AppKit
import UserNotifications
import StretchGoalCore

@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private(set) var authorized = false

    override init() {
        super.init()
        center.delegate = self
        let move = UNNotificationAction(identifier: Action.move, title: "Move (3 min)", options: [.foreground])
        let stretch = UNNotificationAction(identifier: Action.stretch, title: "Stretch", options: [.foreground])
        let nudge = UNNotificationCategory(identifier: Category.nudge, actions: [move, stretch], intentIdentifiers: [])
        center.setNotificationCategories([nudge])
        Task { await refreshAuthorization() }
    }

    func requestAuthorization() async {
        authorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func refreshAuthorization() async {
        authorized = await center.notificationSettings().authorizationStatus == .authorized
    }

    func nudge(sitMinutes: Int) {
        let content = UNMutableNotificationContent()
        let seed = sitMinutes + Int(Date.now.timeIntervalSince1970 / 900)
        content.title = Quips.nudgeTitle(minutes: sitMinutes, seed: seed)
        content.body = Quips.nudgeBody(seed: seed)
        content.sound = .default
        content.categoryIdentifier = Category.nudge
        content.interruptionLevel = .timeSensitive
        center.add(UNNotificationRequest(identifier: "nudge", content: content, trigger: nil))
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        await MainActor.run {
            let kind = action == Action.stretch ? "stretch" : "move"
            if let url = URL(string: "stretchgoal://session/\(kind)") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    enum Action {
        static let move = "move"
        static let stretch = "stretch"
    }

    enum Category {
        static let nudge = "nudge"
    }
}
