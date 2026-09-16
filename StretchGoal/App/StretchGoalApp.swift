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
    static let leaderboard = "leaderboard"
}
