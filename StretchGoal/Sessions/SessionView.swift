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
            }
        }
        .frame(width: 360, height: 300)
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
            Text("Take a break").font(.title2.bold())
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
                    breathingOrb(step: current.step, remaining: current.remaining)
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
            ProgressView(value: Double(elapsed), total: Double(session.totalSeconds))
            Button("Cancel", role: .cancel) {
                model.sessions.cancel()
                dismissWindow(id: WindowID.session)
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(24)
    }

    private func breathingOrb(step: SessionStep, remaining: Int) -> some View {
        let scale: CGFloat = step.title == "Inhale" ? 1.0 : step.title == "Exhale" ? 0.55 : 0.8
        return VStack(spacing: 10) {
            Circle()
                .fill(.blue.gradient.opacity(0.7))
                .frame(width: 120, height: 120)
                .scaleEffect(scale)
                .animation(.easeInOut(duration: 3.6), value: step.title)
            Text(step.title).font(.title2.weight(.semibold))
            Text("\(remaining)").font(.title3.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func finished(_ session: GuidedSession) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundStyle(.green)
            Text("\(session.title) done").font(.title2.bold())
            Text(session.kind.credit == .breakTaken ? "Break logged. Sitting timer reset." : "Mindful minute logged.")
                .foregroundStyle(.secondary)
            Button("Close") {
                model.sessions.cancel()
                dismissWindow(id: WindowID.session)
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
