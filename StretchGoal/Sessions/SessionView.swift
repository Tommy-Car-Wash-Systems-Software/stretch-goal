import SwiftUI
import StretchGoalCore

struct SessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        let runner = model.sessions
        Group {
            switch runner.phase {
            case .idle:
                picker
            case let .running(session):
                running(session, elapsed: runner.elapsed)
            case let .finished(session):
                finished(session)
            case let .failed(session):
                failed(session)
            }
        }
        .frame(width: 360, height: 380)
        .background(.regularMaterial)
        .onOpenURL { url in
            guard url.host() == "session",
                  let raw = url.pathComponents.dropFirst().first,
                  let kind = SessionKind(rawValue: raw) else { return }
            model.start(kind)
            NSApp.activate()
        }
    }

    private var picker: some View {
        VStack(spacing: 12) {
            Text(Quips.sessionPickerTitle).font(.title2.bold())
            Text(Quips.sessionPickerSubtitle).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            ForEach(SessionKind.allCases) { kind in
                let s = GuidedSession.standard(kind)
                Button {
                    model.start(kind)
                } label: {
                    Label("\(s.title)  ·  \(s.subtitle)", systemImage: s.symbol)
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            }
        }
        .padding(24)
    }

    private func running(_ session: GuidedSession, elapsed: Int) -> some View {
        let current = session.step(at: elapsed)
        let remaining = max(0, session.totalSeconds - elapsed)
        return VStack(spacing: 14) {
            HStack {
                Label(session.title, systemImage: session.symbol).font(.headline)
                Spacer()
                Text(Self.clock(remaining)).font(.headline.monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer()
            if let current {
                if session.kind == .breathe {
                    breathingOrb(step: current.step, index: current.index, remaining: current.remaining)
                } else {
                    Text(current.step.title)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                    if !current.step.detail.isEmpty {
                        Text(current.step.detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("\(current.remaining)s")
                        .font(.system(size: 40, weight: .light, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                }
            }
            Spacer()
            if model.sessions.activeSeconds > 0 {
                Label("hands off the keyboard: \(Int(model.sessions.allowedActiveSeconds - model.sessions.activeSeconds))s of typing left before this doesn't count",
                      systemImage: "keyboard")
                    .font(.caption2).foregroundStyle(.orange).lineLimit(2).multilineTextAlignment(.center)
            }
            ProgressView(value: Double(elapsed), total: Double(session.totalSeconds))
            Button("Cancel", role: .cancel) {
                model.sessions.cancel()
                dismissWindow(id: WindowID.session)
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(24)
    }

    private func breathingOrb(step: SessionStep, index: Int, remaining: Int) -> some View {
        // Box breathing: inhale (grow), hold (stay big), exhale (shrink), hold (stay small).
        let phase = index % 4
        let scale: CGFloat = (phase == 0 || phase == 1) ? 1.0 : 0.5
        return VStack(spacing: 10) {
            Circle()
                .fill(.blue.gradient.opacity(0.75))
                .frame(width: 110, height: 110)
                .scaleEffect(scale)
                .animation(phase == 1 || phase == 3 ? .none : .easeInOut(duration: 3.8), value: index)
                .frame(height: 120)
            Text(step.title).font(.title2.weight(.semibold))
            Text("\(remaining)").font(.title3.monospacedDigit()).foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
    }

    private func finished(_ session: GuidedSession) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundStyle(.green)
            Text("\(session.title) done").font(.title2.bold())
            Text(Quips.sessionDone(session.kind, seed: Int(Date.now.timeIntervalSince1970 / 60)))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Close") {
                model.sessions.cancel()
                dismissWindow(id: WindowID.session)
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
    }

    private func failed(_ session: GuidedSession) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "xmark.circle.fill").font(.system(size: 48)).foregroundStyle(.red)
            Text("\(session.title) didn't count").font(.title2.bold())
            Text(Quips.sessionFailed(session.kind, seed: Int(Date.now.timeIntervalSince1970 / 60)))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Close") {
                    model.sessions.cancel()
                    dismissWindow(id: WindowID.session)
                }
                .keyboardShortcut(.cancelAction)
                Button("Try again") { model.start(session.kind) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
