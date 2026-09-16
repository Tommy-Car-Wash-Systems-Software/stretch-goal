import Foundation
import Observation
import StretchGoalCore

@Observable
@MainActor
final class SessionRunner {
    enum Phase: Equatable {
        case idle
        case running(GuidedSession)
        case finished(GuidedSession)
        /// Too much keyboard/mouse input during the session. No credit.
        case failed(GuidedSession)
    }

    private(set) var phase: Phase = .idle
    private(set) var startedAt: Date?
    private(set) var elapsed: Int = 0
    /// Seconds of input observed during the current session.
    private(set) var activeSeconds: Double = 0
    var onComplete: ((SessionKind) -> Void)?
    /// Injected so tests and previews do not touch CoreGraphics.
    var idleSeconds: () -> TimeInterval = { .infinity }

    private static let tick: Double = 0.2
    private static let inputGraceAtStart: Double = 1.5

    private var ticker: Task<Void, Never>?

    var session: GuidedSession? {
        switch phase {
        case .idle: nil
        case let .running(s), let .finished(s), let .failed(s): s
        }
    }

    var allowedActiveSeconds: Double { session?.kind.allowedActiveSeconds ?? 0 }


    var isRunning: Bool { if case .running = phase { true } else { false } }

    func start(_ session: GuidedSession) {
        ticker?.cancel()
        phase = .running(session)
        startedAt = .now
        elapsed = 0
        activeSeconds = 0
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int(Self.tick * 1000)))
                guard let self else { return }
                self.tick()
            }
        }
    }

    func cancel() {
        ticker?.cancel()
        ticker = nil
        phase = .idle
        startedAt = nil
        elapsed = 0
        activeSeconds = 0
    }

    private func tick() {
        guard case let .running(session) = phase, let startedAt else { return }
        let since = Date.now.timeIntervalSince(startedAt)
        elapsed = Int(since)

        // The click that started the session resets idle time; ignore the first moment.
        if since > Self.inputGraceAtStart, idleSeconds() < Self.tick * 2 {
            activeSeconds += Self.tick
            if activeSeconds > session.kind.allowedActiveSeconds {
                ticker?.cancel()
                ticker = nil
                phase = .failed(session)
                return
            }
        }

        if elapsed >= session.totalSeconds {
            ticker?.cancel()
            ticker = nil
            phase = .finished(session)
            onComplete?(session.kind)
        }
    }
}
