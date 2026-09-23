import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?
    @State private var confirmRemove = false
    @State private var removeError: String?

    var body: some View {
        @Bindable var prefs = model.prefs
        Form {
            Section("Team") {
                TextField("Nickname", text: $prefs.nickname)
                    .help("Shown on the team leaderboard once sharing is turned on")
                    .onSubmit { if prefs.sharingEnabled { model.setSharing(true) } }
                Toggle("Share my daily totals with the team", isOn: Binding(
                    get: { prefs.sharingEnabled },
                    set: { model.setSharing($0) }
                ))
                Text("Publishes breaks, water, breathing, eye rests, steps and active time for each day to the shared folder. Raw activity never leaves this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
                LabeledContent("Shared folder") {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(model.sync.folderURL?.path.replacingOccurrences(of: NSHomeDirectory(), with: "~") ?? "not found")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2).truncationMode(.middle)
                        HStack {
                            Button("Choose…") { chooseFolder() }
                            if SharedFolderLocator.override != nil {
                                Button("Use default") { model.chooseSharedFolder(nil) }
                            }
                        }
                    }
                }
                LabeledContent("Status", value: model.sync.status.label)
                HStack {
                    Button("Stop sharing and remove my files…", role: .destructive) { confirmRemove = true }
                    Spacer()
                    Text("Deletes only your folder. Everyone else's stays.").font(.caption).foregroundStyle(.tertiary)
                }
                .confirmationDialog("Remove your files from the shared folder?", isPresented: $confirmRemove) {
                    Button("Remove my files", role: .destructive) {
                        do { try model.stopSharingAndRemoveFiles(); removeError = nil } catch { removeError = error.localizedDescription }
                    }
                } message: {
                    Text("Sharing turns off and your profile and daily files are deleted from the team folder. Your local history stays. You can share again any time.")
                }
                if let removeError { Text(removeError).font(.caption).foregroundStyle(.red) }
            }

            Section("Nudges") {
                Stepper("Remind me after \(prefs.nudgeAfterMinutes) min of sitting", value: $prefs.nudgeAfterMinutes, in: 15...120, step: 5)
                Stepper("Repeat every \(prefs.nudgeRepeatMinutes) min", value: $prefs.nudgeRepeatMinutes, in: 5...60, step: 5)
                Picker("Style", selection: $prefs.nudgeStyle) {
                    ForEach(NudgeStyle.allCases) { style in Text(style.title).tag(style) }
                }
                Text(prefs.nudgeStyle.detail).font(.caption).foregroundStyle(.secondary)
                Button("Preview nudge") { model.previewNudge() }
                LabeledContent("Notifications") {
                    if model.notifier.authorized {
                        Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Allow in System Settings…") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }

            Section("Reminders") {
                Toggle("Remind me to drink water", isOn: $prefs.waterReminderEnabled)
                Stepper("After \(prefs.waterReminderMinutes) min without logging any", value: $prefs.waterReminderMinutes, in: 30...180, step: 15)
                    .disabled(!prefs.waterReminderEnabled)
                Toggle("Remind me to log steps", isOn: $prefs.stepsReminderEnabled)
                DatePicker("Once a day at", selection: minuteBinding($prefs.stepsReminderMinute), displayedComponents: .hourAndMinute)
                    .disabled(!prefs.stepsReminderEnabled)
                Text("Only during work hours, only if there's nothing logged yet. Steps can be corrected for today and the two days before, from the Log… button or the reminder.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Work hours") {
                Toggle("Only track during work hours", isOn: $prefs.workHoursEnabled)
                DatePicker("Start", selection: minuteBinding($prefs.workStartMinute), displayedComponents: .hourAndMinute)
                    .disabled(!prefs.workHoursEnabled)
                DatePicker("End", selection: minuteBinding($prefs.workEndMinute), displayedComponents: .hourAndMinute)
                    .disabled(!prefs.workHoursEnabled)
            }

            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                    .disabled(!LoginItem.isInstalledCopy)
                if !LoginItem.isInstalledCopy {
                    Text("Only the copy in /Applications can launch at login. This one is running from \(Bundle.main.bundlePath).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                LabeledContent("Data folder") {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([model.storeDirectory]) }
                }
            }

            Section("About") {
                LabeledContent("Version", value: model.version)
                LabeledContent("Member ID", value: model.memberId)
                LabeledContent("Device ID", value: model.deviceId)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .task { await model.notifier.refreshAuthorization() }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Use this folder"
        panel.message = "Pick the team's shared Stretch Goal folder (inside the OneDrive library everyone syncs)."
        if let root = SharedFolderLocator.libraryRoot() { panel.directoryURL = root }
        if panel.runModal() == .OK, let url = panel.url { model.chooseSharedFolder(url) }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = LoginItem.isEnabled
        }
    }

    private func minuteBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }
}
