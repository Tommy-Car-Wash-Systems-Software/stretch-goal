import SwiftUI

@main
struct StretchGoalApp: App {
    @State private var model = AppModel()

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
            ContentUnavailableView("Leaderboard arrives in phase 3", systemImage: "trophy")
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
