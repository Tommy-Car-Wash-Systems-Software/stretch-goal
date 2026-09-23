import Foundation
import Observation
import OSLog
import StretchGoalCore

/// Asks GitHub for the latest release tag every few hours. No auth, public repo, 60 req/h limit
/// is not a concern at one call per six hours.
@Observable
@MainActor
final class UpdateChecker {
    private(set) var latest: String?
    private(set) var checkedAt: Date?

    private let current: String
    private let url = URL(string: "https://api.github.com/repos/Tommy-Car-Wash-Systems-Software/stretch-goal/releases/latest")!
    private let log = Logger(subsystem: "com.tommycarwash.StretchGoal", category: "updates")
    private var task: Task<Void, Never>?

    init(currentVersion: String) {
        current = currentVersion
    }

    var updateAvailable: String? {
        guard let latest, Self.isNewer(latest, than: current) else { return nil }
        return latest
    }

    func start() {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.check()
                try? await Task.sleep(for: .seconds(6 * 3600))
            }
        }
    }

    func check() async {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let tag = json["tag_name"] as? String {
                latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                checkedAt = .now
            }
        } catch {
            log.notice("update check failed: \(error.localizedDescription)")
        }
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").compactMap { Int($0) }
        let pb = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
