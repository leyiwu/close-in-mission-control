// Draws the app icon and writes a 1024×1024 PNG. Run through scripts/make-icon.sh.
import AppKit

let size = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

func withShadow(blur: CGFloat, offset: CGFloat, alpha: CGFloat, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: -offset)
    shadow.shadowColor = NSColor.black.withAlphaComponent(alpha)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

// Background tile, in the standard macOS icon grid (824 pt tile on a 1024 pt canvas).
let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
withShadow(blur: 24, offset: 12, alpha: 0.3) {
    color(0x24466F).setFill()
    tile.fill()
}
NSGradient(starting: color(0x4D86C4), ending: color(0x1D3557))!.draw(in: tile, angle: -90)

// A window thumbnail.
let window = NSRect(x: 272, y: 300, width: 520, height: 372)
let windowPath = NSBezierPath(roundedRect: window, xRadius: 40, yRadius: 40)
withShadow(blur: 36, offset: 18, alpha: 0.45) {
    color(0x2A2C31).setFill()
    windowPath.fill()
}
color(0xFFFFFF, 0.16).setStroke()
windowPath.lineWidth = 4
windowPath.stroke()
color(0xFFFFFF, 0.10).setFill()
for (index, width) in [300.0, 220.0, 260.0].enumerated() {
    NSBezierPath(
        roundedRect: NSRect(x: window.minX + 150, y: window.maxY - 150 - Double(index) * 70, width: width, height: 26),
        xRadius: 13, yRadius: 13
    ).fill()
}

// The close button, centred on the thumbnail's top-left corner.
let radius: CGFloat = 112
let center = NSPoint(x: window.minX, y: window.maxY)
let disc = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
withShadow(blur: 22, offset: 10, alpha: 0.4) {
    color(0xF5F5F7).setFill()
    disc.fill()
}
color(0x000000, 0.18).setStroke()
disc.lineWidth = 4
disc.stroke()

let arm: CGFloat = 38
let cross = NSBezierPath()
cross.move(to: NSPoint(x: center.x - arm, y: center.y - arm))
cross.line(to: NSPoint(x: center.x + arm, y: center.y + arm))
cross.move(to: NSPoint(x: center.x - arm, y: center.y + arm))
cross.line(to: NSPoint(x: center.x + arm, y: center.y - arm))
cross.lineWidth = 24
cross.lineCapStyle = .round
color(0x292929).setStroke()
cross.stroke()

NSGraphicsContext.current = nil
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try rep.representation(using: .png, properties: [:])!.write(to: output)
