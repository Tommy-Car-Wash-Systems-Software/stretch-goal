import SwiftUI
import StretchGoalCore

@main
struct StretchGoalApp: App {
    @State private var model: AppModel

    init() {
        Self.exitIfAnotherInstanceIsRunning()
        _model = State(initialValue: AppModel())
    }

    /// Two copies (say, /Applications and a dev build) both writing the day file corrupts it.
    /// The one already running wins; this one hands over and quits.
    private static func exitIfAnotherInstanceIsRunning() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard let other = others.first else { return }
        other.activate()
        exit(0)
    }

    var body: some Scene {
        MenuBarExtra("Stretch Goal", systemImage: "figure.walk") {
            MenuBarView()
                .environment(model)
        }
        .menuBarExtraStyle(.window)

        Window("Break", id: WindowID.session) {
            SessionView()
                .environment(model)
        }
        .windowResizability(.contentSize)
        .windowLevel(.floating)
        .defaultPosition(.center)
        .handlesExternalEvents(matching: ["session"])

        Window("History", id: WindowID.history) {
            HistoryView()
                .environment(model)
        }
        .defaultSize(width: 520, height: 420)

        Window("Leaderboard", id: WindowID.leaderboard) {
            ContentUnavailableView("Leaderboard", systemImage: "trophy", description: Text(Quips.leaderboardPlaceholder))
                .frame(minWidth: 420, minHeight: 320)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

enum WindowID {
    static let session = "session"
    static let history = "history"
    static let leaderboard = "leaderboard"
}
