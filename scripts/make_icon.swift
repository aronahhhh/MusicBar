import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = rootURL.appendingPathComponent("Resources")
let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset")
let sourceURL = resourcesURL.appendingPathComponent("SourceAssets/MusicBarIcon.png")
let icnsURL = resourcesURL.appendingPathComponent("MusicBar.icns")

try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSGraphicsContext.current?.imageInterpolation = .high

    let background = NSBezierPath(roundedRect: rect, xRadius: size * 0.225, yRadius: size * 0.225)
    NSColor(calibratedWhite: 0.045, alpha: 1).setFill()
    background.fill()

    let ringRect = rect.insetBy(dx: size * 0.075, dy: size * 0.075)
    let ring = NSBezierPath(roundedRect: ringRect, xRadius: size * 0.18, yRadius: size * 0.18)
    NSColor(calibratedWhite: 1, alpha: 0.07).setStroke()
    ring.lineWidth = max(1, size * 0.012)
    ring.stroke()

    let pillRect = NSRect(
        x: size * 0.2,
        y: size * 0.46,
        width: size * 0.6,
        height: size * 0.18
    )
    let pill = NSBezierPath(roundedRect: pillRect, xRadius: pillRect.height / 2, yRadius: pillRect.height / 2)
    NSColor(calibratedWhite: 1, alpha: 0.96).setFill()
    pill.fill()

    let dotRect = NSRect(
        x: pillRect.minX + size * 0.055,
        y: pillRect.midY - size * 0.038,
        width: size * 0.076,
        height: size * 0.076
    )
    NSColor(calibratedRed: 0.06, green: 0.62, blue: 0.68, alpha: 1).setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    let bars = [
        (x: size * 0.42, height: size * 0.09),
        (x: size * 0.50, height: size * 0.14),
        (x: size * 0.58, height: size * 0.07)
    ]

    NSColor(calibratedWhite: 0.06, alpha: 1).setFill()
    for bar in bars {
        let barRect = NSRect(
            x: bar.x,
            y: pillRect.midY - bar.height / 2,
            width: size * 0.025,
            height: bar.height
        )
        NSBezierPath(roundedRect: barRect, xRadius: barRect.width / 2, yRadius: barRect.width / 2).fill()
    }

    let baseRect = NSRect(
        x: size * 0.36,
        y: size * 0.32,
        width: size * 0.28,
        height: size * 0.035
    )
    let base = NSBezierPath(roundedRect: baseRect, xRadius: baseRect.height / 2, yRadius: baseRect.height / 2)
    NSColor(calibratedRed: 0.93, green: 0.25, blue: 0.34, alpha: 0.92).setFill()
    base.fill()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "MusicBarIcon", code: 1)
    }

    try data.write(to: url, options: .atomic)
}

let master = drawIcon(size: 1024)
try writePNG(master, to: sourceURL)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in sizes {
    try writePNG(drawIcon(size: size), to: iconsetURL.appendingPathComponent(name))
}

func appendBigEndianUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndianValue = value.bigEndian
    withUnsafeBytes(of: &bigEndianValue) { bytes in
        data.append(contentsOf: bytes)
    }
}

func appendOSType(_ type: String, to data: inout Data) {
    data.append(type.data(using: .ascii)!)
}

let icnsChunks: [(type: String, file: String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

var body = Data()
for chunk in icnsChunks {
    let pngData = try Data(contentsOf: iconsetURL.appendingPathComponent(chunk.file))
    appendOSType(chunk.type, to: &body)
    appendBigEndianUInt32(UInt32(pngData.count + 8), to: &body)
    body.append(pngData)
}

var icns = Data()
appendOSType("icns", to: &icns)
appendBigEndianUInt32(UInt32(body.count + 8), to: &icns)
icns.append(body)
try icns.write(to: icnsURL, options: .atomic)
