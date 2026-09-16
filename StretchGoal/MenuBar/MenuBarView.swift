import SwiftUI
import StretchGoalCore

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            goals
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            Image(systemName: "figure.walk")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading) {
                Text("Stretch Goal").font(.headline)
                Text(model.today.description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(model.score.total) pts")
                .font(.headline.monospacedDigit())
        }
    }

    private var goals: some View {
        Grid(alignment: .leading, verticalSpacing: 6) {
            goalRow("figure.walk", "Breaks", model.summary.breaks, model.rules.breaks.goal)
            goalRow("drop.fill", "Water", model.summary.waterTaps, model.rules.water.goal)
            goalRow("wind", "Mindful", model.summary.mindful, model.rules.mindful.goal)
        }
    }

    private func goalRow(_ symbol: String, _ title: String, _ count: Int, _ goal: Int) -> some View {
        GridRow {
            Label(title, systemImage: symbol)
            Spacer()
            Text("\(count)/\(goal)")
                .monospacedDigit()
                .foregroundStyle(count >= goal ? .green : .secondary)
        }
    }

    private var footer: some View {
        HStack {
            Button("Leaderboard") { openWindow(id: WindowID.leaderboard) }
            Button("Settings…") { openSettings() }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }
}
