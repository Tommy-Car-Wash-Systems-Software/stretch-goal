import AppKit
import SwiftUI
import StretchGoalCore

struct LeaderboardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings
    @State private var showLastWeek = false

    private var week: Week {
        let current = Week(containing: model.today)
        return showLastWeek ? current.previous : current
    }

    var body: some View {
        let entries = model.leaderboard(for: week)
        VStack(spacing: 0) {
            header
            Divider()
            if !model.prefs.sharingEnabled {
                sharingOff
            } else if entries.count <= 1 {
                lonely(entries)
            } else {
                table(entries)
            }
            Divider()
            footer
        }
        .frame(minWidth: 640, minHeight: 360)
    }

    private var header: some View {
        HStack {
            Picker("", selection: $showLastWeek) {
                Text("This week").tag(false)
                Text("Last week").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            Text("\(week.monday.date().formatted(.dateTime.month(.abbreviated).day())) – \(week.sunday.date().formatted(.dateTime.month(.abbreviated).day()))")
                .foregroundStyle(.secondary)
            Spacer()
            statusLabel
        }
        .padding(12)
    }

    private var statusLabel: some View {
        HStack(spacing: 6) {
            if model.sync.isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Circle().fill(statusColor).frame(width: 8, height: 8)
            }
            Text(statusText).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch model.sync.status {
        case .ok: .green
        case .sharingOff: .secondary
        case .folderMissing, .failed: .orange
        }
    }

    private var statusText: String {
        switch model.sync.status {
        case .ok:
            let age = Date.now.timeIntervalSince(model.sync.snapshot.readAt)
            let when = age < 90 ? "just now" : "\(Int(age / 60)) min ago"
            let skipped = model.sync.snapshot.skippedFiles
            return "synced \(when) · \(model.sync.snapshot.memberCount) sharing" + (skipped > 0 ? " · \(skipped) files skipped" : "")
        default:
            return model.sync.status.label
        }
    }

    private func table(_ entries: [LeaderboardEntry]) -> some View {
        Table(entries) {
            TableColumn("#") { e in Text("\(e.rank)").monospacedDigit().foregroundStyle(e.rank <= 3 ? .primary : .secondary) }.width(30)
            TableColumn("Who") { e in
                HStack(spacing: 6) {
                    if e.rank == 1 { Image(systemName: "crown.fill").foregroundStyle(.yellow) }
                    Text(e.nickname).fontWeight(e.memberId == model.memberId ? .bold : .regular)
                    if e.memberId == model.memberId { Text("you").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            TableColumn("Points") { e in Text("\(e.points)").monospacedDigit().fontWeight(.semibold) }.width(70)
            TableColumn("Streak") { e in
                HStack(spacing: 3) {
                    if e.streak > 0 { Image(systemName: "flame.fill").foregroundStyle(.orange) }
                    Text("\(e.streak)").monospacedDigit()
                }
            }.width(70)
            TableColumn("Perfect days") { e in Text("\(e.goalDays)").monospacedDigit() }.width(90)
            TableColumn("Steps") { e in Text(e.steps.formatted()).monospacedDigit() }.width(80)
            TableColumn("Today") { e in
                if e.goalsMetToday { Image(systemName: "checkmark.seal.fill").foregroundStyle(.green) }
            }.width(50)
        }
    }

    private var sharingOff: some View {
        ContentUnavailableView {
            Label("You're not on the board yet", systemImage: "trophy")
        } description: {
            Text("Turn on sharing to publish your daily totals and see the team. Only totals leave your Mac, and you pick the name.")
        } actions: {
            Button("Turn on sharing") { model.setSharing(true) }.buttonStyle(.borderedProminent)
            Button("Settings…") { openSettings() }
        }
    }

    private func lonely(_ entries: [LeaderboardEntry]) -> some View {
        ContentUnavailableView {
            Label("it's just you so far", systemImage: "person")
        } description: {
            Text("recruit someone. peer pressure needs peers. you have \(entries.first?.points ?? 0) points this week and nobody to lord it over.")
        }
    }

    private var footer: some View {
        HStack {
            Button("Refresh") { Task { await model.sync.refresh() } }
                .disabled(!model.prefs.sharingEnabled || model.sync.isRefreshing)
            if let url = model.sync.folderURL {
                Button("Show shared folder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
            Spacer()
            Text("points recompute from everyone's daily counts. nobody's file is trusted, including yours.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(10)
    }
}
