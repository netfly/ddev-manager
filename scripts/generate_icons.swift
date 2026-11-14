import AppKit

// Renders the app icon and the menu bar template icon from the SVG masters in design/.
// Run from the repo root:  swift scripts/generate_icons.swift
//
//   design/app-icon.svg      1024x1024, macOS icon grid (824px tile), DDEV mark + wordmark
//   design/menubar-icon.svg  DDEV mark only, solid black (used as a template image)

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
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    ctx.imageInterpolation = .high
    NSGraphicsContext.current = ctx
    draw(NSRect(x: 0, y: 0, width: pixelsWide, height: pixelsHigh))
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG")
    }
    return data
}

func loadSVG(_ path: String) -> NSImage {
    guard let image = NSImage(contentsOf: URL(fileURLWithPath: path)) else {
        fatalError("Could not load \(path)")
    }
    return image
}

let root = FileManager.default.currentDirectoryPath
let appIconSVG = loadSVG("\(root)/design/app-icon.svg")
let menuBarSVG = loadSVG("\(root)/design/menubar-icon.svg")

func appIconPNG(pixelSize: Int) -> Data {
    let size = CGFloat(pixelSize)
    return renderPNG(pixelsWide: pixelSize, pixelsHigh: pixelSize) { rect in
        // Standard macOS icon drop shadow beneath the 824/1024 tile.
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowOffset = NSSize(width: 0, height: -size * 0.012)
        shadow.shadowBlurRadius = size * 0.03
        shadow.set()
        appIconSVG.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }
}

// Menu bar canvas in points; the mark (90:69) is fit to `markHeight` and centered.
let menuBarSize = NSSize(width: 22, height: 18)
let markHeight: CGFloat = 16

func menuBarPNG(scale: Int) -> Data {
    let s = CGFloat(scale)
    return renderPNG(pixelsWide: Int(menuBarSize.width * s), pixelsHigh: Int(menuBarSize.height * s)) { rect in
        let h = markHeight * s
        let w = h * menuBarSVG.size.width / menuBarSVG.size.height
        let target = NSRect(x: (rect.width - w) / 2, y: (rect.height - h) / 2, width: w, height: h)
        menuBarSVG.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
    }
}

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
    try appIconPNG(pixelSize: entry.px).write(to: URL(fileURLWithPath: "\(appIconDir)/\(entry.name)"))
    print("wrote \(entry.name) (\(entry.px)px)")
}

for (name, scale) in [("menubar.png", 1), ("menubar@2x.png", 2), ("menubar@3x.png", 3)] {
    try menuBarPNG(scale: scale).write(to: URL(fileURLWithPath: "\(menuBarDir)/\(name)"))
    print("wrote \(name)")
}

print("Done.")
