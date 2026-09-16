import SwiftUI
import StretchGoalCore

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            HStack(alignment: .center, spacing: 16) {
                RingsView(
                    progress: [
                        Double(model.day.summary.breaks) / Double(model.rules.breaks.goal),
                        Double(model.day.summary.waterTaps) / Double(model.rules.water.goal),
                        Double(model.day.summary.mindful) / Double(model.rules.mindful.goal),
                    ],
                    colors: [.green, .blue, .purple]
                )
                .frame(width: 96, height: 96)
                goals
            }
            water
            Divider()
            breaks
            Divider()
            WeekStripView(statuses: model.weekStatuses(), today: model.today)
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
    }

    private var header: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stretch Goal").font(.headline)
                    Text(sittingLine(at: context.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(model.score.total) pts").font(.headline.monospacedDigit())
                    if model.streak > 0 {
                        Label("\(model.streak) day streak", systemImage: "flame.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private func sittingLine(at now: Date) -> String {
        if model.locked { return "Away" }
        let sit = Int(model.sittingSeconds(at: now))
        guard sit > 0 else { return "Not sitting" }
        return "Sitting for \(Self.duration(sit))"
    }

    private var goals: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
            goalRow("figure.walk", .green, "Breaks", model.day.summary.breaks, model.rules.breaks.goal)
            goalRow("drop.fill", .blue, "Water", model.day.summary.waterTaps, model.rules.water.goal)
            goalRow("wind", .purple, "Mindful", model.day.summary.mindful, model.rules.mindful.goal)
            Divider().gridCellUnsizedAxes(.horizontal)
            GridRow {
                Label("Active", systemImage: "clock").foregroundStyle(.secondary)
                Text(Self.duration(model.day.summary.activeSeconds)).monospacedDigit().foregroundStyle(.secondary)
            }
            GridRow {
                Label("Longest sit", systemImage: "chair").foregroundStyle(.secondary)
                Text(Self.duration(model.day.summary.longestSitSeconds)).monospacedDigit().foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }

    private func goalRow(_ symbol: String, _ color: Color, _ title: String, _ count: Int, _ goal: Int) -> some View {
        GridRow {
            Label { Text(title) } icon: { Image(systemName: symbol).foregroundStyle(color) }
            Text("\(count)/\(goal)")
                .monospacedDigit()
                .fontWeight(count >= goal ? .semibold : .regular)
                .foregroundStyle(count >= goal ? color : .primary)
        }
    }

    private var water: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<model.rules.water.goal, id: \.self) { i in
                    Image(systemName: i < model.day.summary.waterTaps ? "drop.fill" : "drop")
                        .foregroundStyle(i < model.day.summary.waterTaps ? .blue : .secondary)
                        .font(.caption)
                }
            }
            Spacer()
            Button { model.undoWater() } label: { Image(systemName: "minus") }
                .disabled(model.day.waterEntriesMl.isEmpty)
                .help("Undo last drink")
            Button("250 ml") { model.logWater(ml: 250) }
            Button("500 ml") { model.logWater(ml: 500) }
        }
        .controlSize(.small)
    }

    private var breaks: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TAKE A BREAK").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(SessionKind.allCases) { kind in
                let s = GuidedSession.standard(kind)
                Button {
                    model.start(kind)
                    openWindow(id: WindowID.session)
                    NSApp.activate()
                } label: {
                    HStack {
                        Image(systemName: s.symbol).frame(width: 18)
                        Text(s.title)
                        Spacer()
                        Text(s.subtitle).foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("History") { openWindow(id: WindowID.history); NSApp.activate() }
            Button("Leaderboard") { openWindow(id: WindowID.leaderboard); NSApp.activate() }
            Button("Settings…") { openSettings(); NSApp.activate() }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }

    static func duration(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(String(format: "%02d", m))m" : "\(m)m"
    }
}
