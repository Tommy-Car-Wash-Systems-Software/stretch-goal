import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        @Bindable var prefs = model.prefs
        Form {
            Section("You") {
                TextField("Nickname", text: $prefs.nickname)
                    .help("Shown on the team leaderboard once sharing is turned on")
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

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
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
