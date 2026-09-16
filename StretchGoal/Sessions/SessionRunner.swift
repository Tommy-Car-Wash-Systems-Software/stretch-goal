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
    }

    private(set) var phase: Phase = .idle
    private(set) var startedAt: Date?
    private(set) var elapsed: Int = 0
    var onComplete: ((SessionKind) -> Void)?

    private var ticker: Task<Void, Never>?

    var session: GuidedSession? {
        switch phase {
        case .idle: nil
        case let .running(s), let .finished(s): s
        }
    }

    var isRunning: Bool { if case .running = phase { true } else { false } }

    func start(_ session: GuidedSession) {
        ticker?.cancel()
        phase = .running(session)
        startedAt = .now
        elapsed = 0
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
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
    }

    private func tick() {
        guard case let .running(session) = phase, let startedAt else { return }
        elapsed = Int(Date.now.timeIntervalSince(startedAt))
        if elapsed >= session.totalSeconds {
            ticker?.cancel()
            ticker = nil
            phase = .finished(session)
            onComplete?(session.kind)
        }
    }
}
