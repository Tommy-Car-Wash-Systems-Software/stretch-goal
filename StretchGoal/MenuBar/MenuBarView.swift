import SwiftUI
import StretchGoalCore

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var editingSteps = false
    @State private var stepsDraft = ""
    @FocusState private var stepsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            HStack(alignment: .center, spacing: 16) {
                RingsView(
                    progress: [
                        Double(model.day.summary.breaks) / Double(model.rules.breaks.goal),
                        Double(model.day.summary.waterMl) / Double(model.rules.water.goalMl),
                        Double(model.day.summary.mindful) / Double(model.rules.mindful.goal),
                    ],
                    colors: [.green, .blue, .purple]
                )
                .frame(width: 96, height: 96)
                goals
            }
            water
            steps
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
            let status = model.statusLine(at: context.date)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(status.headline).font(.headline).contentTransition(.numericText())
                    Spacer()
                    Text("\(model.score.total) pts").font(.headline.monospacedDigit())
                        .help(pointsBreakdown)
                }
                Text(status.quip).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack {
                    Label(Quips.streak(model.streak), systemImage: model.streak > 0 ? "flame.fill" : "flame")
                        .font(.caption).foregroundStyle(model.streak > 0 ? .orange : .secondary)
                        .lineLimit(1)
                    Spacer()
                    if let rank = model.myRankLine {
                        Label(rank, systemImage: "trophy").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
        }
    }

    private var pointsBreakdown: String {
        let score = model.score
        var lines = score.parts.map { "\($0.name): \($0.points)" }
        lines.append("All goals bonus: \(score.bonus)")
        lines.append("Streak multiplier: ×\(Double(score.multiplierPercent) / 100)")
        lines.append("Total: (\(score.base) + \(score.bonus)) × \(score.multiplierPercent)% = \(score.total)")
        return lines.joined(separator: "\n")
    }

    private var goals: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
            goalRow("figure.walk", .green, "Breaks", "\(model.day.summary.breaks)/\(model.rules.breaks.goal)", model.rules.breaks.goalMet(model.day.summary.breaks))
            goalRow("drop.fill", .blue, "Water", "\(model.day.summary.waterMl.formatted())/\(model.rules.water.goalMl.formatted()) ml", model.rules.water.goalMet(model.day.summary.waterMl))
            goalRow("wind", .purple, "Mindful", "\(model.day.summary.mindful)/\(model.rules.mindful.goal)", model.rules.mindful.goalMet(model.day.summary.mindful))
            goalRow("eye", .orange, "Eye rests", "\(model.day.summary.eyeRests)/\(model.rules.eyeRests.goal)", model.rules.eyeRests.goalMet(model.day.summary.eyeRests))
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

    private func goalRow(_ symbol: String, _ color: Color, _ title: String, _ value: String, _ met: Bool) -> some View {
        GridRow {
            Label { Text(title) } icon: { Image(systemName: symbol).foregroundStyle(color) }
            Text(value)
                .monospacedDigit()
                .fontWeight(met ? .semibold : .regular)
                .foregroundStyle(met ? color : .primary)
        }
    }

    private var water: some View {
        VStack(alignment: .leading, spacing: 4) {
            waterRow
            if let notice = model.waterNotice {
                Text(notice).font(.caption2).foregroundStyle(.orange).lineLimit(2)
                    .transition(.opacity)
            } else if model.waterAtLimit {
                Text("2 L logged. that's the recommendation for the day.").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .animation(.default, value: model.waterNotice)
    }

    private var waterRow: some View {
        HStack(spacing: 8) {
            let glasses = model.rules.water.glasses(model.day.summary.waterMl)
            HStack(spacing: 3) {
                ForEach(0..<model.rules.water.goalGlasses, id: \.self) { i in
                    Image(systemName: i < glasses ? "drop.fill" : "drop")
                        .foregroundStyle(i < glasses ? .blue : .secondary)
                        .font(.caption)
                }
            }
            .help("one drop per 250 ml glass. 500 ml fills two.")
            Spacer()
            Button { model.undoWater() } label: { Image(systemName: "minus") }
                .disabled(model.day.waterEntries.isEmpty)
                .help("Undo last drink")
            Button("250 ml") { model.logWater(ml: 250) }.help("a glass").disabled(model.waterAtLimit)
            Button("500 ml") { model.logWater(ml: 500) }.help("a bottle").disabled(model.waterAtLimit)
        }
        .controlSize(.small)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label { Text("Steps") } icon: { Image(systemName: "shoeprints.fill").foregroundStyle(.teal) }
                    .font(.callout)
                Text("\(model.day.summary.steps.formatted()) / \(model.rules.steps.goal.formatted())")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(model.rules.steps.goalMet(model.day.summary.steps) ? .teal : .secondary)
                Spacer()
                Button(editingSteps ? "Done" : "Log") {
                    editingSteps.toggle()
                    if editingSteps { stepsDraft = ""; stepsFocused = true }
                }
                .controlSize(.small)
            }
            ProgressView(value: Double(min(model.day.summary.steps, model.rules.steps.goal)), total: Double(model.rules.steps.goal))
                .tint(.teal)
            if editingSteps {
                HStack(spacing: 6) {
                    TextField("today's total from your phone", text: $stepsDraft)
                        .textFieldStyle(.roundedBorder)
                        .focused($stepsFocused)
                        .onSubmit(commitStepsDraft)
                    Button("Set") { commitStepsDraft() }.disabled(Int(stepsDraft.filter(\.isNumber)) == nil)
                    Button("+500") { model.addSteps(500) }
                    Button("+1k") { model.addSteps(1000) }
                }
                .controlSize(.small)
                Text("manual for the humble. watch sync lands with the iOS app, for the chronically optimized.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func commitStepsDraft() {
        if let total = Int(stepsDraft.filter(\.isNumber)) { model.setSteps(total) }
        stepsDraft = ""
        editingSteps = false
    }

    private var breaks: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("TAKE A BREAK").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text("· \(Quips.sessionPickerTitle)").font(.caption2).foregroundStyle(.tertiary)
            }
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
