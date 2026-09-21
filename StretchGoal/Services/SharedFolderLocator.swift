import Foundation
import StretchGoalCore

/// Finds the team's shared folder inside whichever OneDrive/SharePoint library the Mac has synced.
enum SharedFolderLocator {
    static let libraryName = "Software Development Team - General"
    private static let overrideKey = "sync.folderPath"

    /// A folder the person picked by hand, if any.
    static var override: URL? {
        get { UserDefaults.standard.string(forKey: overrideKey).map { URL(fileURLWithPath: $0) } }
        set { UserDefaults.standard.set(newValue?.path, forKey: overrideKey) }
    }

    /// The library root, if OneDrive has it mounted. The mount name varies per machine
    /// (`OneDrive-SharedLibraries-TommyCarWashSystems`, sometimes with a numeric suffix).
    static func libraryRoot() -> URL? {
        let cloud = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/CloudStorage")
        let mounts = (try? FileManager.default.contentsOfDirectory(atPath: cloud.path)) ?? []
        return mounts
            .filter { $0.hasPrefix("OneDrive-SharedLibraries-") }
            .sorted()
            .map { cloud.appending(path: $0).appending(path: libraryName) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Where the shared folder is (or should be). Nil when neither an override nor the library exists.
    static func locate() -> URL? {
        if let override, FileManager.default.fileExists(atPath: override.path) { return override }
        return libraryRoot()?.appending(path: SyncFolder.folderName, directoryHint: .isDirectory)
    }
}
