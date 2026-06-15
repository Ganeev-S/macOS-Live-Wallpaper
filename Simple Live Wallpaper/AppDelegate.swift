import AppKit
import SwiftUI
import UniformTypeIdentifiers

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private enum DefaultsKey {
        static let lastWallpaperPath = "lastWallpaperPath"
    }

    private var statusItem: NSStatusItem!
    private var wallpaperWindowController: WallpaperWindowController?
    private var currentWallpaperAccess: [SecurityScopedResourceAccess] = []
    private var uploadPanel: UploadPanelController?

    static var wallpapersDirectory: URL { WallpaperStorage.wallpapersDirectory }

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupMenuBarItem()
        startLastActiveWallpaper()
    }

    func applicationWillTerminate(_ notification: Notification) {
        wallpaperWindowController?.stop()
        currentWallpaperAccess.removeAll()
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: "Live Wallpaper")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let selectItem = NSMenuItem(title: "Select Wallpaper", action: #selector(openWallpapersFolder), keyEquivalent: "")
        selectItem.target = self
        menu.addItem(selectItem)

        let folderItem = NSMenuItem(title: "Choose Save Folder", action: #selector(chooseWallpapersFolder), keyEquivalent: "")
        folderItem.target = self
        menu.addItem(folderItem)

        let uploadItem = NSMenuItem(title: "Upload Wallpaper", action: #selector(openUploadPanel), keyEquivalent: "")
        uploadItem.target = self
        menu.addItem(uploadItem)

        menu.addItem(NSMenuItem.separator())

        let stopItem = NSMenuItem(title: "Stop Wallpaper", action: #selector(stopWallpaper), keyEquivalent: "")
        stopItem.target = self
        menu.addItem(stopItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func openWallpapersFolder() {
        ensureWallpapersFolderSelected(
            message: "Choose the folder that contains your saved live wallpapers."
        ) { [weak self] didSelectFolder in
            guard didSelectFolder else { return }
            self?.showWallpaperPicker()
        }
    }

    @objc private func chooseWallpapersFolder() {
        presentWallpapersFolderChooser(
            message: "Choose where imported wallpaper videos should be saved."
        ) { _ in }
    }

    @objc private func openUploadPanel() {
        ensureWallpapersFolderSelected(
            message: "Choose where imported wallpaper videos should be saved."
        ) { [weak self] didSelectFolder in
            guard didSelectFolder else { return }
            self?.showUploadPanel()
        }
    }

    @objc private func stopWallpaper() {
        wallpaperWindowController?.stop()
        wallpaperWindowController = nil
        currentWallpaperAccess.removeAll()
        UserDefaults.standard.removeObject(forKey: DefaultsKey.lastWallpaperPath)
    }

    // MARK: - Wallpaper Picker

    private func showWallpaperPicker() {
        let access = WallpaperStorage.beginAccessingWallpapersDirectory()

        let panel = NSOpenPanel()
        panel.directoryURL = access.url
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .mpeg4Movie, .movie, .video, .quickTimeMovie,
            UTType(filenameExtension: "mkv") ?? .movie,
            UTType(filenameExtension: "webm") ?? .movie,
            UTType(filenameExtension: "avi") ?? .movie
        ]
        panel.title = "Choose a Wallpaper"
        panel.prompt = "Set as Wallpaper"

        panel.begin { [weak self] response in
            defer { access.stopAccessing() }
            guard response == .OK, let url = panel.url else { return }
            self?.applyWallpaper(videoURL: url)
        }
    }

    private func showUploadPanel() {
        let controller = UploadPanelController()
        controller.onWallpaperReady = { [weak self] url in
            self?.applyWallpaper(videoURL: url)
            self?.uploadPanel = nil
        }
        self.uploadPanel = controller
        controller.show()
    }

    // MARK: - Wallpaper Application

    func applyWallpaper(videoURL: URL) {
        wallpaperWindowController?.stop()
        wallpaperWindowController = nil
        currentWallpaperAccess.removeAll()

        var access: [SecurityScopedResourceAccess] = []
        if let directoryAccess = WallpaperStorage.beginAccessingDirectoryIfNeeded(containing: videoURL) {
            access.append(directoryAccess)
        }
        access.append(SecurityScopedResourceAccess(url: videoURL))
        currentWallpaperAccess = access

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            showError(title: "Wallpaper Not Found", message: "The selected video could not be found at:\n\(videoURL.path)")
            currentWallpaperAccess.removeAll()
            return
        }

        // Create and start the new wallpaper window
        let controller = WallpaperWindowController(videoURL: videoURL)
        controller.start()
        wallpaperWindowController = controller

        UserDefaults.standard.set(videoURL.path, forKey: DefaultsKey.lastWallpaperPath)

        LockScreenHelper.setLockScreenWallpaper(from: videoURL)
    }

    private func startLastActiveWallpaper() {
        guard let path = UserDefaults.standard.string(forKey: DefaultsKey.lastWallpaperPath) else { return }
        let url = URL(fileURLWithPath: path)
        let directoryAccess = WallpaperStorage.beginAccessingDirectoryIfNeeded(containing: url)
        let fileAccess = SecurityScopedResourceAccess(url: url)
        defer {
            directoryAccess?.stopAccessing()
            fileAccess.stopAccessing()
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.lastWallpaperPath)
            return
        }

        applyWallpaper(videoURL: url)
    }

    // MARK: - Folder Selection

    private func ensureWallpapersFolderSelected(message: String, completion: @escaping (Bool) -> Void) {
        guard !WallpaperStorage.hasSelectedDirectory else {
            completion(true)
            return
        }

        presentWallpapersFolderChooser(message: message, completion: completion)
    }

    private func presentWallpapersFolderChooser(message: String, completion: @escaping (Bool) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Choose Wallpaper Save Folder"
        panel.message = message
        panel.prompt = "Use Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                completion(false)
                return
            }

            do {
                try WallpaperStorage.saveSelectedWallpapersDirectory(url)
                completion(true)
            } catch {
                self?.showError(title: "Could Not Save Folder", message: error.localizedDescription)
                completion(false)
            }
        }
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
