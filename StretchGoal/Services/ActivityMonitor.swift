import AppKit
import CoreGraphics

/// Samples system idle time on a timer and tracks lock, sleep and fast-user-switch state.
@MainActor
final class ActivityMonitor {
    typealias Handler = @MainActor (_ idleSeconds: TimeInterval, _ locked: Bool) -> Void

    private let handler: Handler
    private var timer: Timer?
    private var observers: [any NSObjectProtocol] = []
    private(set) var locked = false

    init(interval: TimeInterval = 10, handler: @escaping Handler) {
        self.handler = handler
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        observe()
        sample()
    }

    private func observe() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()

        let lockNames: [(NotificationCenter, Notification.Name, Bool)] = [
            (workspace, NSWorkspace.screensDidSleepNotification, true),
            (workspace, NSWorkspace.screensDidWakeNotification, false),
            (workspace, NSWorkspace.willSleepNotification, true),
            (workspace, NSWorkspace.didWakeNotification, false),
            (workspace, NSWorkspace.sessionDidResignActiveNotification, true),
            (workspace, NSWorkspace.sessionDidBecomeActiveNotification, false),
            (distributed, Notification.Name("com.apple.screenIsLocked"), true),
            (distributed, Notification.Name("com.apple.screenIsUnlocked"), false),
        ]
        for (center, name, isLocked) in lockNames {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setLocked(isLocked) }
            })
        }
    }

    private func setLocked(_ value: Bool) {
        guard value != locked else { return }
        locked = value
        sample()
    }

    private func sample() {
        handler(Self.idleSeconds(), locked)
    }

    /// Event types that mean a human touched the machine. The "any event" counter also resets
    /// on system-generated events (display sleep/wake, lock screen), which produced phantom
    /// input during guided sessions.
    private static let userInputEvents: [CGEventType] = [
        .keyDown, .mouseMoved, .scrollWheel,
        .leftMouseDown, .rightMouseDown, .otherMouseDown,
        .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
    ]

    static func idleSeconds() -> TimeInterval {
        userInputEvents
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? .infinity
    }
}
