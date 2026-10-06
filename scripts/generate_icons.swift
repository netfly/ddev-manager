import AppKit
import CoreText

let fontName = "HelveticaNeue-CondensedBold"

func font(_ size: CGFloat) -> NSFont {
    NSFont(name: fontName, size: size) ?? NSFont.boldSystemFont(ofSize: size)
}

func fittingFont(text: String, maxWidth: CGFloat, maxHeight: CGFloat) -> NSFont {
    var size = maxHeight
    while size > 1 {
        let f = font(size)
        let w = (text as NSString).size(withAttributes: [.font: f]).width
        if w <= maxWidth { return f }
        size -= 1
    }
    return font(1)
}

/// Draws `text` centered on its actual visual ink bounds (via CTLineGetImageBounds),
/// not on font ascent/descent/advance-width metrics — those pad unevenly around a
/// single glyph like "D" and make it look off-center even though the box math is right.
func drawCentered(_ text: String, font: NSFont, color: NSColor, in rect: NSRect, context: CGContext) {
    let attrString = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
    let line = CTLineCreateWithAttributedString(attrString)
    let inkBounds = CTLineGetImageBounds(line, context)
    guard !inkBounds.isEmpty else { return }
    let origin = NSPoint(
        x: rect.minX + (rect.width - inkBounds.width) / 2 - inkBounds.minX,
        y: rect.minY + (rect.height - inkBounds.height) / 2 - inkBounds.minY
    )
    context.saveGState()
    context.textPosition = CGPoint(x: origin.x, y: origin.y)
    CTLineDraw(line, context)
    context.restoreGState()
}

/// Renders into an explicit bitmap context sized exactly `pixelsWide` x `pixelsHigh`,
/// bypassing NSImage.lockFocus's Retina backing-scale doubling.
func renderPNG(pixelsWide: Int, pixelsHigh: Int, draw: (NSRect) -> Void) -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelsWide,
        pixelsHigh: pixelsHigh,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { fatalError("Could not create bitmap rep") }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(NSRect(x: 0, y: 0, width: pixelsWide, height: pixelsHigh))
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG")
    }
    return data
}

func appIconPNG(pixelSize: Int) -> Data {
    let size = CGFloat(pixelSize)
    return renderPNG(pixelsWide: pixelSize, pixelsHigh: pixelSize) { rect in
        let radius = size * 0.22
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()

        let gradient = NSGradient(
            starting: NSColor(calibratedRed: 0.06, green: 0.09, blue: 0.16, alpha: 1),
            ending: NSColor(calibratedRed: 0.14, green: 0.19, blue: 0.30, alpha: 1)
        )
        gradient?.draw(in: rect, angle: -90)

        let barHeight = size * 0.09
        NSColor(calibratedRed: 0.22, green: 0.78, blue: 0.85, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: size, height: barHeight).fill()

        let text = "DDEV"
        let f = fittingFont(text: text, maxWidth: size * 0.82, maxHeight: size * 0.52)
        let attrs: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: NSColor.white]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let origin = NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2 + barHeight * 0.4)
        (text as NSString).draw(at: origin, withAttributes: attrs)
    }
}

func menuBarPNG(pixelsWide: Int, pixelsHigh: Int) -> Data {
    renderPNG(pixelsWide: pixelsWide, pixelsHigh: pixelsHigh) { rect in
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06),
                                 xRadius: rect.width * 0.22, yRadius: rect.width * 0.22)
        NSColor.black.withAlphaComponent(0.9).setStroke()
        path.lineWidth = rect.width * 0.08
        path.stroke()

        let text = "D"
        let f = fittingFont(text: text, maxWidth: rect.width * 0.6, maxHeight: rect.height * 0.62)
        let context = NSGraphicsContext.current!.cgContext
        drawCentered(text, font: f, color: .black, in: rect, context: context)
    }
}

let root = FileManager.default.currentDirectoryPath
let appIconDir = "\(root)/App/Assets.xcassets/AppIcon.appiconset"
let menuBarDir = "\(root)/App/Assets.xcassets/MenuBarIcon.imageset"
try FileManager.default.createDirectory(atPath: appIconDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(atPath: menuBarDir, withIntermediateDirectories: true)

let appIconSizes: [(name: String, px: Int)] = [
    ("icon_16.png", 16), ("icon_16@2x.png", 32),
    ("icon_32.png", 32), ("icon_32@2x.png", 64),
    ("icon_128.png", 128), ("icon_128@2x.png", 256),
    ("icon_256.png", 256), ("icon_256@2x.png", 512),
    ("icon_512.png", 512), ("icon_512@2x.png", 1024),
]

for entry in appIconSizes {
    let data = appIconPNG(pixelSize: entry.px)
    try data.write(to: URL(fileURLWithPath: "\(appIconDir)/\(entry.name)"))
    print("wrote \(entry.name) (\(entry.px)px)")
}

let menuBarScales: [(name: String, scale: Int)] = [
    ("menubar.png", 1), ("menubar@2x.png", 2), ("menubar@3x.png", 3),
]

for entry in menuBarScales {
    let data = menuBarPNG(pixelsWide: 18 * entry.scale, pixelsHigh: 18 * entry.scale)
    try data.write(to: URL(fileURLWithPath: "\(menuBarDir)/\(entry.name)"))
    print("wrote \(entry.name)")
}

print("Done.")
