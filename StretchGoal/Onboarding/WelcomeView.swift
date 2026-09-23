import AppKit
import SwiftUI
import StretchGoalCore

struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    var body: some View {
        @Bindable var prefs = model.prefs
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stretch Goal").font(.title.bold())
                    Text("the chair is winning. let's fix that.").foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                feature("figure.seated.side", .green, "It notices how long you've been sitting", "and slides a card under the menu bar when it's been too long. One click starts a real break.")
                feature("drop.fill", .blue, "Water, steps, breathing, eye rests", "each with a daily goal from actual health guidance. Hit them for points and a streak.")
                feature("trophy", .orange, "A weekly team leaderboard", "if you opt in. Only daily totals leave your Mac, and you pick the name.")
                feature("lock.shield", .purple, "Nobody cheats", "type during a walk break and it doesn't count. Water stops at 2 L. Points recompute from raw counts.")
            }

            Divider()

            Form {
                TextField("Nickname on the leaderboard", text: $prefs.nickname)
                Toggle("Share my daily totals with the team", isOn: Binding(get: { prefs.sharingEnabled }, set: { model.setSharing($0) }))
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .disabled(!LoginItem.isInstalledCopy)
                    .onChange(of: launchAtLogin) { _, on in
                        do { try LoginItem.setEnabled(on); loginError = nil } catch { loginError = error.localizedDescription; launchAtLogin = LoginItem.isEnabled }
                    }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                LabeledContent("Notifications") {
                    if model.notifier.authorized {
                        Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Allow") { Task { await model.notifier.requestAuthorization() } }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(height: 190)

            HStack {
                Text("everything's adjustable later in Settings. goals aren't, on purpose.").font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button("Let's go") {
                    model.prefs.onboarded = true
                    dismissWindow(id: WindowID.welcome)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 560)
        .task { await model.notifier.refreshAuthorization() }
    }

    private func feature(_ symbol: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundStyle(tint).frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
