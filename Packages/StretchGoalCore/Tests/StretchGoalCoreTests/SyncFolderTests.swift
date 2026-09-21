import Testing
import Foundation
@testable import StretchGoalCore

@Suite struct SyncFolderTests {
    func makeFolder() throws -> SyncFolder {
        let root = FileManager.default.temporaryDirectory.appending(path: "sg-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return SyncFolder(root: root)
    }

    @Test func filenameParsing() {
        let parsed = SyncFolder.parseDailyFilename("2026-09-16.de96b3f2.json")
        #expect(parsed?.date == Fixtures.day("2026-09-16"))
        #expect(parsed?.deviceId == "de96b3f2")
        #expect(SyncFolder.parseDailyFilename("2026-09-16.json") == nil)
        #expect(SyncFolder.parseDailyFilename("notes.txt") == nil)
        #expect(SyncFolder.parseDailyFilename(".DS_Store") == nil)
    }

    @Test func writeThenListThenDecode() throws {
        let folder = try makeFolder()
        let cal = Fixtures.calendar
        let week = Week(containing: Fixtures.day("2026-09-16"), calendar: cal)

        try folder.write(profile: MemberProfile(memberId: "amanda", nickname: "Amanda"))
        try folder.write(summary: Fixtures.perfect("2026-09-15", member: "amanda"))
        try folder.write(summary: Fixtures.summary("2026-09-16", member: "amanda", device: "d1", breaks: 3))
        try folder.write(summary: Fixtures.summary("2026-09-16", member: "amanda", device: "d2", breaks: 5))
        try folder.write(summary: Fixtures.summary("2026-09-01", member: "amanda", breaks: 9)) // outside window
        try folder.write(summary: Fixtures.summary("2026-09-16", member: "brianp", breaks: 1))
        try folder.writeReadme()

        #expect(folder.memberIds() == ["amanda", "brianp"])
        #expect(folder.profileURLs().count == 1)
        let files = folder.dailyFiles(in: [week])
        #expect(files.count == 4)
        #expect(files.filter { $0.memberId == "amanda" && $0.date == Fixtures.day("2026-09-16") }.count == 2)

        let summaries = files.compactMap { file in
            (try? Data(contentsOf: file.url)).flatMap { SyncFolder.decodeSummary($0, expecting: file) }
        }
        #expect(summaries.count == 4)

        let board = Leaderboard.compute(week: week, today: Fixtures.day("2026-09-16"),
                                        profiles: [MemberProfile(memberId: "amanda", nickname: "Amanda")],
                                        summaries: summaries, calendar: cal)
        #expect(board.map(\.nickname) == ["Amanda", "brianp"])
        #expect(board[0].points == 145 + 52) // perfect Tuesday, then max(3,5) breaks × 1.05 carried streak
        #expect(FileManager.default.fileExists(atPath: folder.root.appending(path: "README.md").path))
    }

    @Test func rejectsFilesThatLieAboutThemselves() throws {
        let folder = try makeFolder()
        let file = SyncFolder.DailyFile(url: folder.dailyURL(memberId: "amanda", date: Fixtures.day("2026-09-16"), deviceId: "x"),
                                        memberId: "amanda", date: Fixtures.day("2026-09-16"), deviceId: "x")
        let wrongMember = try Codec.encode(Fixtures.summary("2026-09-16", member: "brianp"))
        #expect(SyncFolder.decodeSummary(wrongMember, expecting: file) == nil)
        let wrongDate = try Codec.encode(Fixtures.summary("2026-09-15", member: "amanda"))
        #expect(SyncFolder.decodeSummary(wrongDate, expecting: file) == nil)
        var future = Fixtures.summary("2026-09-16", member: "amanda"); future.schemaVersion = 9
        #expect(SyncFolder.decodeSummary(try Codec.encode(future), expecting: file) == nil)
        #expect(SyncFolder.decodeSummary(Data("garbage".utf8), expecting: file) == nil)
    }

    @Test func snapshotRoundTrip() throws {
        let snap = SyncSnapshot(profiles: [MemberProfile(memberId: "a", nickname: "A", joined: Date(timeIntervalSince1970: 500))],
                                summaries: [Fixtures.summary("2026-09-16", member: "a"), Fixtures.summary("2026-09-16", member: "b")],
                                readAt: Date(timeIntervalSince1970: 1_000), skippedFiles: 2)
        let decoded = try Codec.decode(SyncSnapshot.self, from: Codec.encode(snap))
        #expect(decoded == snap)
        #expect(decoded.memberCount == 2)
    }
}
