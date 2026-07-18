import Cocoa

// Renders the app icon at a given pixel size. Usage: icon <size> <outPath>
let size = CGFloat(Int(CommandLine.arguments[1]) ?? 1024)
let outPath = CommandLine.arguments[2]

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Apple macOS icon grid: rounded-rect content inset ~10%, corner radius ~0.2237 of content side
let inset = size * 0.10
let side = size - inset * 2
let radius = side * 0.2237
let squircle = NSRect(x: inset, y: inset, width: side, height: side)
let path = NSBezierPath(roundedRect: squircle, xRadius: radius, yRadius: radius)

// drop shadow under the squircle (subtle, Apple-like)
NSGraphicsContext.saveGraphicsState()
let sh = NSShadow()
sh.shadowColor = NSColor(white: 0, alpha: 0.28)
sh.shadowBlurRadius = size * 0.02
sh.shadowOffset = NSSize(width: 0, height: -size * 0.012)
sh.set()
NSColor.black.setFill()
path.fill()
NSGraphicsContext.restoreGraphicsState()

// gradient background (indigo -> violet), clipped to squircle
path.addClip()
let grad = NSGradient(colors: [
    NSColor(srgbRed: 0.40, green: 0.42, blue: 0.86, alpha: 1),
    NSColor(srgbRed: 0.29, green: 0.24, blue: 0.60, alpha: 1),
])!
grad.draw(in: squircle, angle: -90)

// subtle top highlight
let hi = NSGradient(colors: [
    NSColor(white: 1, alpha: 0.18),
    NSColor(white: 1, alpha: 0.0),
])!
hi.draw(in: NSRect(x: inset, y: inset + side*0.55, width: side, height: side*0.45), angle: -90)

// white bar-chart glyph (matches the menu bar's chart.bar.xaxis)
let cfg = NSImage.SymbolConfiguration(pointSize: side * 0.5, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let sym = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: nil)?
                .withSymbolConfiguration(cfg) {
    let s = sym.size
    let r = NSRect(x: (size - s.width)/2, y: (size - s.height)/2, width: s.width, height: s.height)
    sym.draw(in: r)
}

NSGraphicsContext.restoreGraphicsState()
if let png = rep.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(Int(size)) -> \(outPath)")
}
