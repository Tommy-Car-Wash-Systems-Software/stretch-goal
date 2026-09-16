import Foundation

public enum SessionKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case move, breathe, stretch, eyeRest

    public var id: String { rawValue }

    public enum Credit: Sendable { case breakTaken, mindful }

    public var credit: Credit {
        switch self {
        case .move, .stretch: .breakTaken
        case .breathe, .eyeRest: .mindful
        }
    }
}

public struct SessionStep: Hashable, Sendable {
    public let title: String
    public let detail: String
    public let seconds: Int

    public init(_ title: String, _ detail: String = "", seconds: Int) {
        self.title = title
        self.detail = detail
        self.seconds = seconds
    }
}

public struct GuidedSession: Hashable, Sendable {
    public let kind: SessionKind
    public let title: String
    public let subtitle: String
    public let symbol: String
    public let steps: [SessionStep]

    public var totalSeconds: Int { steps.reduce(0) { $0 + $1.seconds } }

    /// The step in progress at `elapsed` seconds, with seconds remaining in that step.
    public func step(at elapsed: Int) -> (index: Int, step: SessionStep, remaining: Int)? {
        var offset = 0
        for (i, step) in steps.enumerated() {
            if elapsed < offset + step.seconds {
                return (i, step, offset + step.seconds - elapsed)
            }
            offset += step.seconds
        }
        return nil
    }

    public static func standard(_ kind: SessionKind) -> GuidedSession {
        switch kind {
        case .move:
            GuidedSession(kind: kind, title: "Move", subtitle: "3 min", symbol: "figure.walk", steps: [
                SessionStep("Walk away from your desk", "Touch grass. Literally. Refill your water, take the stairs, go outside. Back when the timer ends.", seconds: 180),
            ])
        case .breathe:
            GuidedSession(kind: kind, title: "Breathe", subtitle: "4-4-4-4", symbol: "wind",
                          steps: Array(repeating: [
                              SessionStep("Inhale", "Through the nose", seconds: 4),
                              SessionStep("Hold", seconds: 4),
                              SessionStep("Exhale", "Slowly, through the mouth", seconds: 4),
                              SessionStep("Hold", seconds: 4),
                          ], count: 8).flatMap { $0 })
        case .stretch:
            GuidedSession(kind: kind, title: "Stretch", subtitle: "Full desk", symbol: "figure.flexibility", steps: [
                SessionStep("Neck rolls", "Slow circles, both directions", seconds: 30),
                SessionStep("Shoulder shrugs", "Up to your ears, hold, drop", seconds: 30),
                SessionStep("Wrist circles", "Both directions, then flex and extend", seconds: 30),
                SessionStep("Seated twist", "Hand on the opposite knee, look over your shoulder. Switch halfway.", seconds: 30),
                SessionStep("Chest opener", "Hands clasped behind you, lift and open", seconds: 30),
                SessionStep("Stand: hamstrings", "Feet together, fold forward, let your arms hang", seconds: 30),
                SessionStep("Stand: calf raises", "Slow up, slow down", seconds: 30),
                SessionStep("Stand: reach up", "Arms overhead, stretch tall, then shake it out. Stretch goal, literally.", seconds: 30),
            ])
        case .eyeRest:
            GuidedSession(kind: kind, title: "Eye rest", subtitle: "20s", symbol: "eye", steps: [
                SessionStep("Look far away", "Something at least 20 feet away. The Jira board doesn't count.", seconds: 20),
            ])
        }
    }
}
