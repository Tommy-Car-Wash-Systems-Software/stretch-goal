import SwiftUI
import StretchGoalCore

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Table(rows) {
            TableColumn("Day") { row in
                Text(row.day.date().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
            }
            TableColumn("Breaks") { row in Text("\(row.breaks)").monospacedDigit() }.width(60)
            TableColumn("Water") { row in Text("\(row.water)").monospacedDigit() }.width(60)
            TableColumn("Mindful") { row in Text("\(row.mindful)").monospacedDigit() }.width(60)
            TableColumn("Steps") { row in Text(row.steps.formatted()).monospacedDigit() }.width(70)
            TableColumn("Active") { row in Text(MenuBarView.duration(row.active)).monospacedDigit() }.width(70)
            TableColumn("Longest sit") { row in Text(MenuBarView.duration(row.longestSit)).monospacedDigit() }.width(80)
            TableColumn("Points") { row in
                HStack {
                    Text("\(row.points)").monospacedDigit().fontWeight(.semibold)
                    if row.allGoals { Image(systemName: "checkmark.seal.fill").foregroundStyle(.green) }
                }
            }.width(80)
        }
        .frame(minWidth: 600, minHeight: 300)
        .overlay {
            if rows.isEmpty {
                ContentUnavailableView("History", systemImage: "calendar", description: Text(Quips.historyEmpty))
            }
        }
    }

    private struct Row: Identifiable {
        let day: DayKey
        let breaks: Int, water: Int, mindful: Int, steps: Int, active: Int, longestSit: Int, points: Int
        let allGoals: Bool
        var id: DayKey { day }
    }

    private var rows: [Row] {
        let history = model.history
        return model.recentDays.prefix(30).map { s in
            let score = Score.daily(s, streak: Streak.carried(into: s.date, history: history, rules: model.rules), rules: model.rules)
            return Row(day: s.date, breaks: s.breaks, water: s.waterTaps, mindful: s.mindful, steps: s.steps, active: s.activeSeconds,
                       longestSit: s.longestSitSeconds, points: score.total, allGoals: score.allGoalsMet)
        }
    }
}
