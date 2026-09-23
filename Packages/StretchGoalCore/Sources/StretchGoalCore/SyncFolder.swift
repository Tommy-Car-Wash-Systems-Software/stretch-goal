import Foundation

/// Layout of the shared folder. One writer per file, always:
///
///     <root>/members/<memberId>/profile.json
///     <root>/members/<memberId>/daily/<yyyy-MM-dd>.<deviceId>.json
///
/// Readers enumerate everyone's files; writers only ever touch their own. Nobody deletes.
public struct SyncFolder: Sendable {
    public static let folderName = "Stretch Goal"

    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public var membersDirectory: URL { root.appending(path: "members", directoryHint: .isDirectory) }

    public func memberDirectory(_ memberId: String) -> URL {
        membersDirectory.appending(path: memberId, directoryHint: .isDirectory)
    }

    public func profileURL(_ memberId: String) -> URL {
        memberDirectory(memberId).appending(path: "profile.json")
    }

    public func dailyDirectory(_ memberId: String) -> URL {
        memberDirectory(memberId).appending(path: "daily", directoryHint: .isDirectory)
    }

    public func dailyURL(memberId: String, date: DayKey, deviceId: String) -> URL {
        dailyDirectory(memberId).appending(path: "\(date).\(deviceId).json")
    }

    /// `2026-09-16.de96b3f2.json` → (2026-09-16, "de96b3f2")
    public static func parseDailyFilename(_ name: String) -> (date: DayKey, deviceId: String)? {
        guard name.hasSuffix(".json") else { return nil }
        let parts = name.dropLast(5).split(separator: ".", maxSplits: 1)
        guard parts.count == 2, let date = DayKey(string: String(parts[0])), !parts[1].isEmpty else { return nil }
        return (date, String(parts[1]))
    }

    // MARK: Writing (own files only)

    public func write(profile: MemberProfile) throws {
        try ensureDirectory(memberDirectory(profile.memberId))
        try Codec.encode(profile).write(to: profileURL(profile.memberId), options: .atomic)
    }

    public func write(summary: DaySummary) throws {
        try ensureDirectory(dailyDirectory(summary.memberId))
        try Codec.encode(summary).write(to: dailyURL(memberId: summary.memberId, date: summary.date, deviceId: summary.deviceId), options: .atomic)
    }

    public func writeReadme() throws {
        try ensureDirectory(membersDirectory)
        let url = root.appending(path: "README.md")
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let text = """
        # Stretch Goal — team sync folder

        Written and read by the Stretch Goal menu bar app. Each person's app writes only its own
        files under `members/<id>/`; everyone's app reads all of them to build the leaderboard.

        Please don't hand-edit or delete anything in here. Points are recomputed from the daily
        counts by every reader, so editing a file can't change a score, but it can break the parse.

        Only daily totals live here (breaks, water, breathing, eye rests, steps, active time).
        Raw activity never leaves anyone's Mac. Sharing is opt-in per person.
        """
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// The one deletion the protocol allows: a member removing their own folder.
    public func removeMember(_ memberId: String) throws {
        let dir = memberDirectory(memberId)
        guard FileManager.default.fileExists(atPath: dir.path) else { return }
        try FileManager.default.removeItem(at: dir)
    }

    private func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    // MARK: Listing (everyone's files)

    public struct DailyFile: Hashable, Sendable {
        public let url: URL
        public let memberId: String
        public let date: DayKey
        public let deviceId: String
    }

    public func memberIds() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: membersDirectory.path)) ?? []
        return names.filter { !$0.hasPrefix(".") }.sorted()
    }

    public func profileURLs() -> [URL] {
        memberIds().map(profileURL).filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Daily files whose filename date falls inside any of `weeks`. Filtering by name means a
    /// reader never opens a file it does not need, which matters on a cloud-backed folder.
    public func dailyFiles(in weeks: [Week]) -> [DailyFile] {
        var result: [DailyFile] = []
        for memberId in memberIds() {
            let dir = dailyDirectory(memberId)
            let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
            for name in names {
                guard let parsed = Self.parseDailyFilename(name), weeks.contains(where: { $0.contains(parsed.date) }) else { continue }
                result.append(DailyFile(url: dir.appending(path: name), memberId: memberId, date: parsed.date, deviceId: parsed.deviceId))
            }
        }
        return result
    }

    /// Decodes a summary, rejecting files whose folder or name disagree with their contents.
    public static func decodeSummary(_ data: Data, expecting file: DailyFile) -> DaySummary? {
        guard let summary = try? Codec.decode(DaySummary.self, from: data),
              summary.schemaVersion == DaySummary.currentSchemaVersion,
              summary.memberId == file.memberId,
              summary.date == file.date else { return nil }
        return summary
    }
}

/// What a reader saw the last time it looked at the shared folder. Cached locally so the
/// leaderboard still renders when the folder is unreachable.
public struct SyncSnapshot: Codable, Hashable, Sendable {
    public var profiles: [MemberProfile]
    public var summaries: [DaySummary]
    public var readAt: Date
    public var skippedFiles: Int

    public init(profiles: [MemberProfile] = [], summaries: [DaySummary] = [], readAt: Date = .now, skippedFiles: Int = 0) {
        self.profiles = profiles
        self.summaries = summaries
        self.readAt = readAt
        self.skippedFiles = skippedFiles
    }

    public var memberCount: Int { Set(summaries.map(\.memberId)).count }
}
