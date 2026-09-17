import Foundation
import OSLog
import ServiceManagement

/// Launch-at-login, restricted to the installed copy so a development build never becomes the
/// login item (which is how two instances ended up running at once).
@MainActor
enum LoginItem {
    private static let log = Logger(subsystem: "com.tommycarwash.StretchGoal", category: "login-item")
    private static let registeredPathKey = "loginItem.registeredPath"

    static var isInstalledCopy: Bool {
        Bundle.main.bundlePath.hasPrefix("/Applications/")
    }

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(Bundle.main.bundlePath, forKey: registeredPathKey)
        } else {
            try SMAppService.mainApp.unregister()
            UserDefaults.standard.removeObject(forKey: registeredPathKey)
        }
    }

    /// If login was enabled from a copy at a different path, re-register from this one so the
    /// system launches the installed app and not a stale build.
    static func healIfNeeded() {
        guard isInstalledCopy, isEnabled else { return }
        let registered = UserDefaults.standard.string(forKey: registeredPathKey)
        guard registered != Bundle.main.bundlePath else { return }
        do {
            try SMAppService.mainApp.unregister()
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(Bundle.main.bundlePath, forKey: registeredPathKey)
            log.notice("re-registered login item from \(registered ?? "unknown") to \(Bundle.main.bundlePath)")
        } catch {
            log.error("login item heal failed: \(error.localizedDescription)")
        }
    }
}
