import AppKit
import SwiftUI
import StretchGoalCore

enum NudgeStyle: String, CaseIterable, Codable, Identifiable {
    case panel, fullScreen, banner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .panel: "Floating panel"
        case .fullScreen: "Full screen"
        case .banner: "System banner only"
        }
    }

    var detail: String {
        switch self {
        case .panel: "A card slides in under the menu bar on every screen. Doesn't steal focus, dismisses itself after a minute."
        case .fullScreen: "Dims every screen until you pick a break or snooze. For when the panel isn't cutting it."
        case .banner: "Just the macOS notification in the corner."
        }
    }
}

/// Shows nudges as borderless non-activating panels so they sit above every app without
/// taking keyboard focus away from whatever the person is typing in.
@MainActor
final class NudgePresenter {
    typealias Action = @MainActor (SessionKind?) -> Void

    private var panels: [NSPanel] = []
    private var autoDismiss: Task<Void, Never>?

    var isShowing: Bool { !panels.isEmpty }

    func show(sitMinutes: Int, style: NudgeStyle, onAction: @escaping Action) {
        dismiss()
        guard style != .banner else { return }

        for screen in NSScreen.screens {
            let content = NudgeView(sitMinutes: sitMinutes, fullScreen: style == .fullScreen) { [weak self] kind in
                self?.dismiss()
                onAction(kind)
            }
            let panel = makePanel(for: screen, fullScreen: style == .fullScreen, content: content)
            panels.append(panel)
            if style == .fullScreen {
                panel.makeKeyAndOrderFront(nil)
            } else {
                panel.orderFrontRegardless()
            }
        }

        if style == .panel {
            autoDismiss = Task { [weak self] in
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                self?.dismiss()
            }
        }
    }

    /// A short, self-dismissing card with no actions: milestones, goals hit, streaks.
    func celebrate(title: String, body: String, symbol: String, tint: Color) {
        dismiss()
        for screen in NSScreen.screens {
            let content = CelebrationView(title: title, body: body, symbol: symbol, tint: tint) { [weak self] in self?.dismiss() }
            let panel = makePanel(for: screen, fullScreen: false, content: content)
            panels.append(panel)
            panel.orderFrontRegardless()
        }
        autoDismiss = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        autoDismiss?.cancel()
        autoDismiss = nil
        for panel in panels { panel.orderOut(nil) }
        panels.removeAll()
    }

    private func makePanel(for screen: NSScreen, fullScreen: Bool, content: some View) -> NSPanel {
        let frame: NSRect
        if fullScreen {
            frame = screen.frame
        } else {
            let size = NSSize(width: 490, height: 132)
            let visible = screen.visibleFrame
            frame = NSRect(x: visible.maxX - size.width - 16, y: visible.maxY - size.height - 12, width: size.width, height: size.height)
        }

        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = fullScreen ? .screenSaver : .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = !fullScreen
        panel.isMovableByWindowBackground = !fullScreen
        panel.animationBehavior = fullScreen ? .none : .utilityWindow
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: content)
        return panel
    }
}

struct CelebrationView: View {
    let title: String
    let body_: String
    let symbol: String
    let tint: Color
    let onTap: () -> Void

    init(title: String, body: String, symbol: String, tint: Color, onTap: @escaping () -> Void) {
        self.title = title
        self.body_ = body
        self.symbol = symbol
        self.tint = tint
        self.onTap = onTap
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 30)).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(body_).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 490, height: 132, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.35)))
        .contentShape(.rect)
        .onTapGesture(perform: onTap)
    }
}

struct NudgeView: View {
    let sitMinutes: Int
    let fullScreen: Bool
    let onAction: (SessionKind?) -> Void

    private var seed: Int { sitMinutes * 7 + Int(Date.now.timeIntervalSince1970 / 900) }

    var body: some View {
        if fullScreen { full } else { compact }
    }

    private var compact: some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 30))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Quips.nudgeTitle(minutes: sitMinutes, seed: seed)).font(.headline).lineLimit(1)
                    Text(Quips.nudgeBody(seed: seed)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 6) {
                    sessionButton(.move, compact: true)
                    sessionButton(.stretch, compact: true)
                    sessionButton(.breathe, compact: true)
                    Spacer()
                    Button(Quips.snooze(seed: seed)) { onAction(nil) }
                        .buttonStyle(NudgeButtonStyle(color: .gray.opacity(0.5), compact: true))
                }
            }
        }
        .padding(16)
        .frame(width: 490, height: 132, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12)))
    }

    private var full: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.72)).ignoresSafeArea()
            VStack(spacing: 22) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
                Text(Quips.nudgeTitle(minutes: sitMinutes, seed: seed))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(Quips.nudgeBody(seed: seed) + " The screen comes back when you do.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    sessionButton(.move, compact: false)
                    sessionButton(.stretch, compact: false)
                    sessionButton(.breathe, compact: false)
                    sessionButton(.eyeRest, compact: false)
                }
                Button(Quips.snooze(seed: seed)) { onAction(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
                    .padding(.top, 8)
            }
            .foregroundStyle(.white)
            .padding(40)
        }
    }

    private func sessionButton(_ kind: SessionKind, compact: Bool) -> some View {
        let s = GuidedSession.standard(kind)
        return Button {
            onAction(kind)
        } label: {
            Label(compact ? s.title : "\(s.title) · \(s.subtitle)", systemImage: s.symbol)
        }
        .buttonStyle(NudgeButtonStyle(color: kind.credit == .breakTaken ? .green : .purple, compact: compact))
    }
}

/// Explicit colors: system prominent buttons render inactive-gray inside a non-key panel.
struct NudgeButtonStyle: ButtonStyle {
    let color: Color
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lineLimit(1)
            .fixedSize()
            .font(compact ? .callout.weight(.medium) : .title3.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 10 : 18)
            .padding(.vertical, compact ? 5 : 12)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1), in: .capsule)
            .contentShape(.capsule)
    }
}
