import Foundation
import StretchGoalCore

/// Local-only persistence: one JSON file per day under Application Support.
struct DayStore: Sendable {
    let directory: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appending(path: "Stretch Goal/days", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func url(for day: DayKey) -> URL {
        directory.appending(path: "\(day).json")
    }

    func load(_ day: DayKey) -> LocalDay? {
        guard let data = try? Data(contentsOf: url(for: day)) else { return nil }
        return try? Codec.decode(LocalDay.self, from: data)
    }

    func save(_ day: LocalDay) {
        do {
            try Codec.encode(day).write(to: url(for: day.date), options: .atomic)
        } catch {
            NSLog("Stretch Goal: failed to save \(day.date): \(error)")
        }
    }

    /// Most recent days first, excluding `excluding`.
    func loadRecent(limit: Int, excluding: DayKey? = nil) -> [LocalDay] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let keys = names
            .filter { $0.hasSuffix(".json") }
            .compactMap { DayKey(string: String($0.dropLast(5))) }
            .filter { $0 != excluding }
            .sorted(by: >)
            .prefix(limit)
        return keys.compactMap(load)
    }
}
