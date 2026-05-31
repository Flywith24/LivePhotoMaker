import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "Assets/DMGBackground.png"
let size = NSSize(width: 640, height: 400)
let image = NSImage(size: size)

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawText(_ text: String, at point: NSPoint, font: NSFont, color: NSColor, alignment: NSTextAlignment = .center, width: CGFloat = 520) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    text.draw(in: NSRect(x: point.x, y: point.y, width: width, height: font.pointSize + 8), withAttributes: attributes)
}

image.lockFocus()

let bounds = NSRect(origin: .zero, size: size)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.12, alpha: 1),
    NSColor(calibratedRed: 0.03, green: 0.31, blue: 0.48, alpha: 1),
    NSColor(calibratedRed: 0.96, green: 0.58, blue: 0.20, alpha: 1)
])!
gradient.draw(in: bounds, angle: -35)

NSColor(calibratedWhite: 1, alpha: 0.12).setFill()
roundedRect(NSRect(x: 34, y: 34, width: 572, height: 332), radius: 28).fill()

NSColor(calibratedWhite: 1, alpha: 0.16).setStroke()
let ring = NSBezierPath(ovalIn: NSRect(x: 88, y: 70, width: 464, height: 260))
ring.lineWidth = 2
ring.stroke()

drawText(
    "LivePhotoMaker",
    at: NSPoint(x: 60, y: 322),
    font: .systemFont(ofSize: 28, weight: .semibold),
    color: .white
)
drawText(
    "Drag the app into Applications",
    at: NSPoint(x: 60, y: 292),
    font: .systemFont(ofSize: 15, weight: .medium),
    color: NSColor(calibratedWhite: 1, alpha: 0.78)
)

let leftSlot = NSRect(x: 118, y: 128, width: 116, height: 116)
let rightSlot = NSRect(x: 406, y: 128, width: 116, height: 116)
NSColor(calibratedWhite: 1, alpha: 0.16).setFill()
roundedRect(leftSlot.insetBy(dx: -18, dy: -18), radius: 24).fill()
roundedRect(rightSlot.insetBy(dx: -18, dy: -18), radius: 24).fill()

if let icon = NSImage(contentsOfFile: "Assets/AppIcon.png") {
    icon.draw(in: leftSlot)
}

NSColor(calibratedWhite: 1, alpha: 0.93).setStroke()
let arrow = NSBezierPath()
arrow.lineWidth = 8
arrow.lineCapStyle = .round
arrow.move(to: NSPoint(x: 270, y: 187))
arrow.line(to: NSPoint(x: 364, y: 187))
arrow.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 364, y: 187))
arrowHead.line(to: NSPoint(x: 342, y: 207))
arrowHead.move(to: NSPoint(x: 364, y: 187))
arrowHead.line(to: NSPoint(x: 342, y: 167))
arrowHead.lineWidth = 8
arrowHead.lineCapStyle = .round
arrowHead.stroke()

NSColor(calibratedWhite: 1, alpha: 0.92).setFill()
let folder = roundedRect(NSRect(x: 424, y: 150, width: 80, height: 58), radius: 10)
folder.fill()
let tab = roundedRect(NSRect(x: 434, y: 202, width: 34, height: 18), radius: 7)
tab.fill()
NSColor(calibratedRed: 0.09, green: 0.34, blue: 0.50, alpha: 0.92).setFill()
NSBezierPath(roundedRect: NSRect(x: 438, y: 162, width: 52, height: 34), xRadius: 8, yRadius: 8).fill()

drawText(
    "LivePhotoMaker.app",
    at: NSPoint(x: 68, y: 94),
    font: .systemFont(ofSize: 13, weight: .medium),
    color: NSColor(calibratedWhite: 1, alpha: 0.78),
    width: 220
)
drawText(
    "Applications",
    at: NSPoint(x: 358, y: 94),
    font: .systemFont(ofSize: 13, weight: .medium),
    color: NSColor(calibratedWhite: 1, alpha: 0.78),
    width: 220
)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render DMG background")
}

let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: outputURL)
