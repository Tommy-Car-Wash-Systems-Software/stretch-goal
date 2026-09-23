import Foundation
import Observation
import OSLog
import StretchGoalCore

/// Publishes this member's daily summary to the shared folder and reads everyone else's.
/// Writer touches only its own files. Reader tolerates missing, slow, or broken files.
@Observable
@MainActor
final class SyncService {
    enum Status: Equatable {
        case sharingOff
        case folderMissing
        case ok
        case failed(String)

        var label: String {
            switch self {
            case .sharingOff: "sharing is off"
            case .folderMissing: "shared folder not found. is OneDrive signed in?"
            case .ok: "synced"
            case let .failed(m): "sync problem: \(m)"
            }
        }
    }

    private(set) var status: Status = .sharingOff
    private(set) var snapshot: SyncSnapshot
    private(set) var folderURL: URL?
    private(set) var isRefreshing = false

    private let cacheURL: URL
    private var pollTask: Task<Void, Never>?
    private var publishTask: Task<Void, Never>?
    private var lastPublished: Date = .distantPast
    private let log = Logger(subsystem: "com.tommycarwash.StretchGoal", category: "sync")

    private static let pollInterval: Duration = .seconds(60)
    private static let readTimeout: Duration = .seconds(3)
    private static let publishThrottle: TimeInterval = 60

    init(cacheDirectory: URL) {
        cacheURL = cacheDirectory.appending(path: "leaderboard-cache.json")
        snapshot = (try? Data(contentsOf: cacheURL)).flatMap { try? Codec.decode(SyncSnapshot.self, from: $0) } ?? SyncSnapshot(readAt: .distantPast)
    }

    var folder: SyncFolder? { folderURL.map(SyncFolder.init(root:)) }

    // MARK: Lifecycle

    func start(enabled: Bool) {
        pollTask?.cancel()
        guard enabled else {
            status = .sharingOff
            folderURL = SharedFolderLocator.locate()
            return
        }
        relocate()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        publishTask?.cancel()
        status = .sharingOff
    }

    func relocate() {
        folderURL = SharedFolderLocator.locate()
        guard let folder else { status = .folderMissing; return }
        do {
            try folder.writeReadme()
            if case .failed = status { status = .ok }
            if status == .folderMissing || status == .sharingOff { status = .ok }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: Publish (own files only)

    /// Throttled: at most one write a minute unless `force` (a scoring event).
    func publish(profile: MemberProfile, summary: DaySummary, force: Bool = false) {
        guard status != .sharingOff, let folder else { return }
        let due = force || Date.now.timeIntervalSince(lastPublished) >= Self.publishThrottle
        guard due else { return }
        publishTask?.cancel()
        publishTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(force ? 1 : 5))
            guard !Task.isCancelled, let self else { return }
            do {
                try folder.write(profile: profile)
                try folder.write(summary: summary)
                self.lastPublished = .now
                if case .failed = self.status { self.status = .ok }
            } catch {
                self.status = .failed(error.localizedDescription)
                self.log.error("publish failed: \(error.localizedDescription)")
            }
        }
    }

    /// Stops sharing and deletes this member's folder. Nobody else's files are touched.
    func removeMyFiles(memberId: String) throws {
        stop()
        guard let folder else { return }
        try folder.removeMember(memberId)
        lastPublished = .distantPast
    }

    // MARK: Read (everyone's files)

    func refresh() async {
        guard status != .sharingOff, !isRefreshing else { return }
        guard let folder, FileManager.default.fileExists(atPath: folder.membersDirectory.path) else {
            status = .folderMissing
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        let today = DayKey(.now)
        let thisWeek = Week(containing: today)
        let files = folder.dailyFiles(in: [thisWeek, thisWeek.previous])
        let profileURLs = folder.profileURLs()

        var summaries: [DaySummary] = []
        var profiles: [MemberProfile] = []
        var skipped = 0

        await withTaskGroup(of: (SyncFolder.DailyFile, Data?).self) { group in
            for file in files {
                group.addTask { (file, await TimeboxedIO.read(file.url, timeout: Self.readTimeout)) }
            }
            for await (file, data) in group {
                if let data, let summary = SyncFolder.decodeSummary(data, expecting: file) {
                    summaries.append(summary)
                } else {
                    skipped += 1
                }
            }
        }
        for url in profileURLs {
            if let data = await TimeboxedIO.read(url, timeout: Self.readTimeout),
               let profile = try? Codec.decode(MemberProfile.self, from: data),
               profile.schemaVersion == MemberProfile.currentSchemaVersion {
                profiles.append(profile)
            } else {
                skipped += 1
            }
        }

        snapshot = SyncSnapshot(profiles: profiles, summaries: summaries, readAt: .now, skippedFiles: skipped)
        status = .ok
        try? Codec.encode(snapshot).write(to: cacheURL, options: .atomic)
        log.notice("refreshed: \(summaries.count) summaries, \(profiles.count) profiles, \(skipped) skipped")
    }
}
