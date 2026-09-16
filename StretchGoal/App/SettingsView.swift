import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            LabeledContent("Version", value: model.version)
            LabeledContent("Member ID", value: model.memberId)
            LabeledContent("Device ID", value: model.deviceId)
        }
        .formStyle(.grouped)
        .frame(width: 380)
    }
}
