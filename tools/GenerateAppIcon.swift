import AppKit

struct IconSlot {
    let logicalSize: Int
    let scale: Int

    var pixelSize: Int { logicalSize * scale }

    var filename: String {
        scale == 1
            ? "AppIcon-\(logicalSize).png"
            : "AppIcon-\(logicalSize)@\(scale)x.png"
    }
}

let slots = [
    IconSlot(logicalSize: 16, scale: 1),
    IconSlot(logicalSize: 16, scale: 2),
    IconSlot(logicalSize: 32, scale: 1),
    IconSlot(logicalSize: 32, scale: 2),
    IconSlot(logicalSize: 128, scale: 1),
    IconSlot(logicalSize: 128, scale: 2),
    IconSlot(logicalSize: 256, scale: 1),
    IconSlot(logicalSize: 256, scale: 2),
    IconSlot(logicalSize: 512, scale: 1),
    IconSlot(logicalSize: 512, scale: 2),
]

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: GenerateAppIcon /path/to/AppIcon.appiconset\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func drawIcon(pixelSize: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
    let scale = CGFloat(pixelSize) / 1024.0

    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else { return image }
    context.scaleBy(x: scale, y: scale)
    NSGraphicsContext.current?.imageInterpolation = .high

    let canvas = NSRect(x: 0, y: 0, width: 1024, height: 1024)
    let outer = NSBezierPath(roundedRect: canvas.insetBy(dx: 56, dy: 56), xRadius: 220, yRadius: 220)
    outer.addClip()

    let background = NSGradient(colors: [
        NSColor(calibratedRed: 0.05, green: 0.17, blue: 0.19, alpha: 1.0),
        NSColor(calibratedRed: 0.08, green: 0.40, blue: 0.38, alpha: 1.0),
        NSColor(calibratedRed: 0.04, green: 0.08, blue: 0.12, alpha: 1.0),
    ])
    background?.draw(in: outer, angle: 35)

    NSColor(calibratedRed: 1.0, green: 0.75, blue: 0.36, alpha: 0.22).setFill()
    NSBezierPath(ovalIn: NSRect(x: 610, y: 610, width: 360, height: 360)).fill()

    NSColor(calibratedWhite: 1.0, alpha: 0.08).setFill()
    NSBezierPath(roundedRect: NSRect(x: 116, y: 716, width: 300, height: 38), xRadius: 19, yRadius: 19).fill()

    let screenRect = NSRect(x: 178, y: 270, width: 668, height: 440)
    let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: 72, yRadius: 72)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 32
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()

    NSColor(calibratedWhite: 0.98, alpha: 0.94).setFill()
    screenPath.fill()

    NSShadow().set()

    let innerRect = screenRect.insetBy(dx: 34, dy: 34)
    let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 48, yRadius: 48)
    innerPath.addClip()

    let innerGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.07, green: 0.12, blue: 0.18, alpha: 1.0),
        NSColor(calibratedRed: 0.08, green: 0.26, blue: 0.24, alpha: 1.0),
    ])
    innerGradient?.draw(in: innerPath, angle: 90)

    NSColor(calibratedRed: 0.31, green: 0.88, blue: 0.68, alpha: 0.85).setStroke()
    let wave = NSBezierPath()
    wave.move(to: NSPoint(x: 230, y: 420))
    wave.curve(to: NSPoint(x: 430, y: 446), controlPoint1: NSPoint(x: 300, y: 530), controlPoint2: NSPoint(x: 352, y: 300))
    wave.curve(to: NSPoint(x: 794, y: 474), controlPoint1: NSPoint(x: 540, y: 650), controlPoint2: NSPoint(x: 642, y: 302))
    wave.lineWidth = 30
    wave.lineCapStyle = .round
    wave.stroke()

    NSColor(calibratedWhite: 1.0, alpha: 0.16).setStroke()
    let horizon = NSBezierPath()
    horizon.move(to: NSPoint(x: 250, y: 560))
    horizon.line(to: NSPoint(x: 774, y: 560))
    horizon.lineWidth = 10
    horizon.lineCapStyle = .round
    horizon.stroke()

    let triangle = NSBezierPath()
    triangle.move(to: NSPoint(x: 460, y: 380))
    triangle.line(to: NSPoint(x: 460, y: 600))
    triangle.line(to: NSPoint(x: 635, y: 490))
    triangle.close()
    NSColor(calibratedRed: 1.0, green: 0.38, blue: 0.28, alpha: 1.0).setFill()
    triangle.fill()

    let stand = NSBezierPath(roundedRect: NSRect(x: 422, y: 210, width: 180, height: 44), xRadius: 22, yRadius: 22)
    NSColor(calibratedWhite: 0.96, alpha: 0.92).setFill()
    stand.fill()

    let base = NSBezierPath(roundedRect: NSRect(x: 332, y: 152, width: 360, height: 54), xRadius: 27, yRadius: 27)
    NSColor(calibratedWhite: 0.93, alpha: 0.82).setFill()
    base.fill()

    let border = NSBezierPath(roundedRect: canvas.insetBy(dx: 60, dy: 60), xRadius: 216, yRadius: 216)
    NSColor(calibratedWhite: 1.0, alpha: 0.16).setStroke()
    border.lineWidth = 8
    border.stroke()

    return image
}

for slot in slots {
    let image = drawIcon(pixelSize: slot.pixelSize)
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fputs("Could not render \(slot.filename)\n", stderr)
        exit(1)
    }

    try png.write(to: outputDirectory.appendingPathComponent(slot.filename))
}
