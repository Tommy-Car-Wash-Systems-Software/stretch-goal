import AppKit
import SwiftUI
import StretchGoalCore

struct ShareView: View {
    @Environment(AppModel.self) private var model
    @State private var image: NSImage?
    @State private var flash: String?

    var body: some View {
        VStack(spacing: 14) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 12))
                    .shadow(radius: 8, y: 4)
            } else {
                ProgressView().frame(height: 300)
            }
            HStack(spacing: 10) {
                Button {
                    copyImage()
                } label: {
                    Label("Copy image", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("c")
                .disabled(image == nil)

                Button {
                    copyText()
                } label: {
                    Label("Copy as text", systemImage: "text.quote")
                }

                if let image {
                    ShareLink(item: Image(nsImage: image), preview: SharePreview("My Stretch Goal day", image: Image(nsImage: image))) {
                        Label("Share…", systemImage: "square.and.arrow.up")
                    }
                }

                Button {
                    save()
                } label: {
                    Label("Save…", systemImage: "square.and.arrow.down")
                }
                .disabled(image == nil)

                Spacer()
                Button {
                    image = ShareCard.render(model: model)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            Text(flash ?? "paste it in Teams. the QR code installs the app. yes, really.")
                .font(.caption)
                .foregroundStyle(flash == nil ? Color.secondary : Color.green)
                .animation(.default, value: flash)
        }
        .padding(16)
        .frame(width: 720)
        .task { image = ShareCard.render(model: model) }
    }

    private func copyImage() {
        guard let image else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
        pb.setString(ShareCard.caption(model: model), forType: .string)
        show("copied. go paste it somewhere people will see it.")
    }

    private func copyText() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(ShareCard.caption(model: model), forType: .string)
        show("text copied.")
    }

    private func save() {
        guard let image, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "stretch-goal-\(model.today).png"
        panel.allowedContentTypes = [.png]
        if panel.runModal() == .OK, let url = panel.url {
            try? png.write(to: url)
            show("saved.")
        }
    }

    private func show(_ text: String) {
        flash = text
        Task {
            try? await Task.sleep(for: .seconds(3))
            flash = nil
        }
    }
}
