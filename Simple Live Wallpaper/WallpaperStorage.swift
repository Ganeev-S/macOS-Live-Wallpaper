import AppKit

final class SecurityScopedResourceAccess {
    let url: URL
    private var didStartAccessing: Bool

    init(url: URL) {
        self.url = url
        self.didStartAccessing = url.startAccessingSecurityScopedResource()
    }

    init(url: URL, alreadyAccessing: Bool) {
        self.url = url
        self.didStartAccessing = alreadyAccessing
    }

    func stopAccessing() {
        guard didStartAccessing else { return }
        url.stopAccessingSecurityScopedResource()
        didStartAccessing = false
    }

    deinit {
        stopAccessing()
    }
}

enum WallpaperStorage {
    private static let selectedDirectoryBookmarkKey = "selectedWallpaperDirectoryBookmark"
    private static let selectedDirectoryPathKey = "selectedWallpaperDirectoryPath"

    static var hasSelectedDirectory: Bool {
        UserDefaults.standard.data(forKey: selectedDirectoryBookmarkKey) != nil
    }

    static var wallpapersDirectory: URL {
        selectedWallpapersDirectory() ?? defaultWallpapersDirectory
    }

    static var generatedFrameURL: URL {
        generatedFramesDirectory.appendingPathComponent("CurrentWallpaperFrame.jpg")
    }

    static func saveSelectedWallpapersDirectory(_ url: URL) throws {
        let access = SecurityScopedResourceAccess(url: url)
        defer { access.stopAccessing() }

        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmark, forKey: selectedDirectoryBookmarkKey)
        UserDefaults.standard.set(url.path, forKey: selectedDirectoryPathKey)
    }

    static func beginAccessingWallpapersDirectory() -> SecurityScopedResourceAccess {
        if let selectedURL = selectedWallpapersDirectory() {
            let didStartAccessing = selectedURL.startAccessingSecurityScopedResource()
            try? FileManager.default.createDirectory(at: selectedURL, withIntermediateDirectories: true)
            return SecurityScopedResourceAccess(url: selectedURL, alreadyAccessing: didStartAccessing)
        }

        try? FileManager.default.createDirectory(at: defaultWallpapersDirectory, withIntermediateDirectories: true)
        return SecurityScopedResourceAccess(url: defaultWallpapersDirectory, alreadyAccessing: false)
    }

    static func beginAccessingDirectoryIfNeeded(containing fileURL: URL) -> SecurityScopedResourceAccess? {
        guard let selectedURL = selectedWallpapersDirectory(),
              fileURL.isContained(in: selectedURL) else {
            return nil
        }

        let didStartAccessing = selectedURL.startAccessingSecurityScopedResource()
        return SecurityScopedResourceAccess(url: selectedURL, alreadyAccessing: didStartAccessing)
    }

    private static var defaultWallpapersDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("LiveWallpaper/Wallpapers", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static var generatedFramesDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("LiveWallpaper/Generated Frames", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func selectedWallpapersDirectory() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: selectedDirectoryBookmarkKey) else {
            return nil
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                try saveSelectedWallpapersDirectory(url)
            }

            return url
        } catch {
            print("[LiveWallpaper] Could not resolve selected wallpaper folder: \(error)")
            UserDefaults.standard.removeObject(forKey: selectedDirectoryBookmarkKey)
            UserDefaults.standard.removeObject(forKey: selectedDirectoryPathKey)
            return nil
        }
    }
}

private extension URL {
    func isContained(in directory: URL) -> Bool {
        let filePath = standardizedFileURL.path
        let directoryPath = directory.standardizedFileURL.path
        return filePath == directoryPath || filePath.hasPrefix(directoryPath + "/")
    }
}
