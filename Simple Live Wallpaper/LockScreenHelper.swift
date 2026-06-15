import AppKit
import AVFoundation

/// Extracts a representative frame and uses it as the static desktop fallback image.
///
/// Note: macOS does not provide a public API for animated lock screen wallpapers.
/// The static image approach is the only reliable, sandboxed-compatible method.
enum LockScreenHelper {

    static func setLockScreenWallpaper(from videoURL: URL) {
        guard let firstFrame = extractFirstUsableFrame(from: videoURL),
              let imageURL = writeDesktopFallbackImage(firstFrame) else { return }

        // Apply to all screens via NSWorkspace
        // This sets the *desktop* wallpaper (which is also shown on the lock screen)
        // using the most power-efficient static method.
        let workspace = NSWorkspace.shared
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .allowClipping: true,
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue
        ]

        for screen in NSScreen.screens {
            do {
                try workspace.setDesktopImageURL(imageURL, for: screen, options: options)
            } catch {
                // Not critical; the live wallpaper window renders on top anyway.
                print("[LiveWallpaper] Could not set desktop image for screen \(screen): \(error)")
            }
        }
    }

    // MARK: - Frame Extraction

    private static func extractFirstUsableFrame(from videoURL: URL) -> CGImage? {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        var firstDecodedFrame: CGImage?
        var lastError: Error?

        // Prefer the exact first frame. If decoding at zero produces a blank frame
        // or fails on a movie that starts between sample times, walk forward briefly.
        for time in candidateFrameTimes() {
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                if firstDecodedFrame == nil {
                    firstDecodedFrame = cgImage
                }
                if !isNearlySolidBlack(cgImage) {
                    return cgImage
                }
            } catch {
                lastError = error
            }
        }

        if let firstDecodedFrame {
            return firstDecodedFrame
        }

        if let lastError {
            print("[LiveWallpaper] Frame extraction failed: \(lastError)")
        }
        return nil
    }

    private static func candidateFrameTimes() -> [CMTime] {
        let sampleSeconds = [0, 1.0 / 60.0, 1.0 / 30.0, 0.1, 0.5, 1.0, 2.0]
        return sampleSeconds
            .map { CMTime(seconds: $0, preferredTimescale: 600) }
    }

    private static func writeDesktopFallbackImage(_ cgImage: CGImage) -> URL? {
        let imageURL = WallpaperStorage.generatedFrameURL
        let bitmap = NSBitmapImageRep(cgImage: cgImage)

        guard let jpegData = bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.95]
        ) else {
            print("[LiveWallpaper] Could not encode lock screen image.")
            return nil
        }

        do {
            try jpegData.write(to: imageURL, options: .atomic)
            return imageURL
        } catch {
            print("[LiveWallpaper] Failed to write lock screen image: \(error)")
            return nil
        }
    }

    private static func isNearlySolidBlack(_ cgImage: CGImage) -> Bool {
        let width = 24
        let height = 24
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        let didDraw = pixels.withUnsafeMutableBytes { pointer -> Bool in
            guard let baseAddress = pointer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: bitmapInfo
                  ) else {
                return false
            }

            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard didDraw else { return false }

        var brightPixelCount = 0
        var totalLuminance = 0

        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = Int(pixels[index])
            let green = Int(pixels[index + 1])
            let blue = Int(pixels[index + 2])
            let luminance = (2_126 * red + 7_152 * green + 722 * blue) / 10_000
            totalLuminance += luminance

            if luminance > 16 {
                brightPixelCount += 1
            }
        }

        let pixelCount = width * height
        let averageLuminance = totalLuminance / pixelCount
        return averageLuminance < 6 && brightPixelCount < 4
    }
}
