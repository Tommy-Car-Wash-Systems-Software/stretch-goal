import SwiftUI
import StretchGoalCore

struct StepsLogView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var drafts: [DayKey: String] = [:]
    @FocusState private var focused: DayKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Log steps").font(.title2.bold())
                Text("today's total off your phone or watch. forgot yesterday? fix it here. older than that is history.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(model.editableDays, id: \.self) { date in
                row(for: date)
            }
            HStack {
                Text("goal \(model.rules.steps.goal.formatted()) · points cap \(model.rules.steps.cap.formatted()) · entries clamp at \(model.rules.steps.maxLogged.formatted())")
                    .font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Button("Done") { dismissWindow(id: WindowID.steps) }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(18)
        .frame(width: 520)
        .onAppear { focused = model.today }
    }

    private func row(for date: DayKey) -> some View {
        let current = model.steps(on: date)
        let label = date == model.today ? "Today" : date == model.today.adding(days: -1) ? "Yesterday" : date.date().formatted(.dateTime.weekday(.wide))
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.headline)
                Text(date.date().formatted(.dateTime.month(.abbreviated).day())).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 96, alignment: .leading)
            Text(current.formatted())
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(model.rules.steps.goalMet(current) ? .teal : .primary)
                .frame(width: 70, alignment: .trailing)
            TextField("new total", text: binding(for: date))
                .textFieldStyle(.roundedBorder)
                .focused($focused, equals: date)
                .onSubmit { commit(date) }
                .frame(width: 110)
            Button("Set") { commit(date) }
                .disabled(Int((drafts[date] ?? "").filter(\.isNumber)) == nil)
            Button("+500") { model.addSteps(500, on: date) }
            Button("+1k") { model.addSteps(1000, on: date) }
            Spacer()
        }
        .controlSize(.small)
    }

    private func binding(for date: DayKey) -> Binding<String> {
        Binding(get: { drafts[date] ?? "" }, set: { drafts[date] = $0 })
    }

    private func commit(_ date: DayKey) {
        if let total = Int((drafts[date] ?? "").filter(\.isNumber)) {
            model.setSteps(total, on: date)
        }
        drafts[date] = ""
    }
}
