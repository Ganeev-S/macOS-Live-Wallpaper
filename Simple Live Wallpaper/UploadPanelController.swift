import AppKit
import AVFoundation
import UniformTypeIdentifiers

/// Imports a video, converts it to HEVC at the selected frame rate, and saves it for reuse.
final class UploadPanelController {

    // MARK: - Public Callback

    var onWallpaperReady: ((URL) -> Void)?

    // MARK: - Private State

    private var progressWindow: NSWindow?
    private var progressBar: NSProgressIndicator?
    private var progressTimer: Timer?

    // MARK: - Entry Point

    func show() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Video to Use as Wallpaper"
        panel.prompt = "Import"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .mpeg4Movie, .movie, .video, .quickTimeMovie,
            UTType(filenameExtension: "mkv") ?? .movie,
            UTType(filenameExtension: "webm") ?? .movie,
            UTType(filenameExtension: "avi") ?? .movie,
        ].compactMap { $0 }

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.askForFrameRate(sourceURL: url)
        }
    }

    // MARK: - Frame Rate Selection

    private func askForFrameRate(sourceURL: URL) {
        let asset = AVURLAsset(url: sourceURL)
        var detectedFPS: Float = 30

        if let track = asset.tracks(withMediaType: .video).first {
            detectedFPS = track.nominalFrameRate
        }

        // Build a simple dialog with an NSPopUpButton for frame rate
        let alert = NSAlert()
        alert.messageText = "Choose Output Frame Rate"
        alert.informativeText = String(format: "Source video is ~%.0f fps. Lower frame rates use less power.", detectedFPS)
        alert.addButton(withTitle: "Convert")
        alert.addButton(withTitle: "Cancel")

        let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 26))
        let fpsOptions: [Float] = [24, 25, 30, 48, 60]
        for fps in fpsOptions {
            popUp.addItem(withTitle: "\(Int(fps)) fps")
            popUp.lastItem?.tag = Int(fps)
        }

        let closest = fpsOptions.min(by: { abs($0 - detectedFPS) < abs($1 - detectedFPS) }) ?? 30
        popUp.selectItem(withTag: Int(closest))

        alert.accessoryView = popUp
        alert.window.initialFirstResponder = popUp

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let selectedFPS = Float(popUp.selectedTag())
        convert(sourceURL: sourceURL, targetFPS: selectedFPS)
    }

    // MARK: - Conversion

    private func convert(sourceURL: URL, targetFPS: Float) {
        showProgressWindow()

        let sourceAccess = SecurityScopedResourceAccess(url: sourceURL)
        let destinationAccess = WallpaperStorage.beginAccessingWallpapersDirectory()
        let asset = AVURLAsset(url: sourceURL)

        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let outputURL = uniqueOutputURL(in: destinationAccess.url, baseName: baseName, targetFPS: targetFPS)

        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHEVCHighestQuality
        ) else {
            sourceAccess.stopAccessing()
            destinationAccess.stopAccessing()
            dismissProgressWindow()
            showError("Could not create export session.")
            return
        }

        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = false

        applyFrameRateComposition(to: session, asset: asset, fps: targetFPS)

        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.progressBar?.doubleValue = Double(session.progress) * 100
            }
        }

        session.exportAsynchronously { [weak self] in
            DispatchQueue.main.async {
                defer {
                    sourceAccess.stopAccessing()
                    destinationAccess.stopAccessing()
                }

                self?.progressTimer?.invalidate()
                self?.dismissProgressWindow()

                switch session.status {
                case .completed:
                    self?.onWallpaperReady?(outputURL)
                case .failed:
                    self?.showError(session.error?.localizedDescription ?? "Unknown error during export.")
                case .cancelled:
                    break
                default:
                    break
                }
            }
        }
    }

    private func uniqueOutputURL(in directory: URL, baseName: String, targetFPS: Float) -> URL {
        let fileManager = FileManager.default
        let sanitizedBaseName = baseName.isEmpty ? "Wallpaper" : baseName
        let suffix = "_hevc_\(Int(targetFPS))fps"
        var candidate = directory.appendingPathComponent("\(sanitizedBaseName)\(suffix).mp4")
        var index = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(sanitizedBaseName)\(suffix)-\(index).mp4")
            index += 1
        }

        return candidate
    }

    private func applyFrameRateComposition(to session: AVAssetExportSession, asset: AVURLAsset, fps: Float) {
        guard let videoTrack = asset.tracks(withMediaType: .video).first else { return }

        let composition = AVMutableVideoComposition(asset: asset) { request in
            request.finish(with: request.sourceImage, context: nil)
        }

        composition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        composition.renderSize = videoTrack.naturalSize

        session.videoComposition = composition
    }

    // MARK: - Progress UI

    private func showProgressWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 90),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Converting Wallpaper..."
        window.center()
        window.isReleasedWhenClosed = false

        let bar = NSProgressIndicator(frame: NSRect(x: 20, y: 30, width: 280, height: 20))
        bar.style = .bar
        bar.minValue = 0
        bar.maxValue = 100
        bar.doubleValue = 0
        bar.isIndeterminate = false

        let label = NSTextField(labelWithString: "Converting to HEVC - please wait...")
        label.frame = NSRect(x: 20, y: 58, width: 280, height: 18)
        label.font = NSFont.systemFont(ofSize: 12)
        label.alignment = .center

        window.contentView?.addSubview(bar)
        window.contentView?.addSubview(label)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.progressWindow = window
        self.progressBar = bar
    }

    private func dismissProgressWindow() {
        progressWindow?.orderOut(nil)
        progressWindow = nil
        progressBar = nil
    }

    // MARK: - Error Display

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Conversion Failed"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
