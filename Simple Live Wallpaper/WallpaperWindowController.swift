import AppKit
import AVFoundation

/// Manages desktop-level windows that play a muted looping video behind Finder icons.
final class WallpaperWindowController {

    // MARK: - Properties

    private let videoURL: URL
    private var windows: [NSWindow] = []
    private var player: AVPlayer?
    private var playerLayers: [AVPlayerLayer] = []
    private var loopObserver: NSObjectProtocol?

    // MARK: - Init

    init(videoURL: URL) {
        self.videoURL = videoURL
    }

    // MARK: - Public Interface

    func start() {
        setupPlayer()
        createWindowsForAllScreens()
        player?.play()
        observeLoop()
    }

    func stop() {
        player?.pause()
        loopObserver.map { NotificationCenter.default.removeObserver($0) }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        playerLayers.removeAll()
        player = nil
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        let asset = AVURLAsset(url: videoURL, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])
        let item = AVPlayerItem(asset: asset)

        if #available(macOS 11.0, *) {
            item.appliesPerFrameHDRDisplayMetadata = false
        }

        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.allowsExternalPlayback = false
        player.preventsDisplaySleepDuringVideoPlayback = false

        self.player = player
    }

    // MARK: - Window Creation

    private func createWindowsForAllScreens() {
        for screen in NSScreen.screens {
            createWindow(for: screen)
        }
    }

    private func createWindow(for screen: NSScreen) {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        window.backgroundColor = .black

        let contentView = NSView(frame: screen.frame)
        contentView.wantsLayer = true

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = contentView.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.isOpaque = true
        playerLayer.contentsScale = screen.backingScaleFactor

        contentView.layer?.addSublayer(playerLayer)
        window.contentView = contentView

        window.orderFront(nil)

        windows.append(window)
        playerLayers.append(playerLayer)
    }

    // MARK: - Loop Observation

    private func observeLoop() {
        guard let player else { return }

        // Seamlessly loop the video when it reaches the end
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            player?.play()
        }
    }
}
