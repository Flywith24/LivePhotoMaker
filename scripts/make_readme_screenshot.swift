import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "Assets/README-Screenshot.png"
let size = NSSize(width: 1440, height: 960)
let image = NSImage(size: size)

func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func text(_ value: String, _ rect: NSRect, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = NSColor(calibratedWhite: 0.08, alpha: 1), alignment: NSTextAlignment = .left) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byTruncatingTail
    value.draw(in: rect, withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ])
}

func label(_ value: String, x: CGFloat, y: CGFloat, w: CGFloat = 180) {
    NSColor(calibratedWhite: 1, alpha: 0.88).setFill()
    rounded(NSRect(x: x, y: y, width: w, height: 44), 22).fill()
    text(value, NSRect(x: x, y: y + 10, width: w, height: 24), size: 15, weight: .medium, color: NSColor(calibratedWhite: 0.08, alpha: 1), alignment: .center)
}

image.lockFocus()

let bounds = NSRect(origin: .zero, size: size)
NSGradient(colors: [
    NSColor(calibratedRed: 0.93, green: 0.98, blue: 1.0, alpha: 1),
    NSColor(calibratedRed: 0.98, green: 0.93, blue: 0.80, alpha: 1)
])!.draw(in: bounds, angle: -25)

NSColor(calibratedWhite: 0, alpha: 0.10).setFill()
rounded(NSRect(x: 110, y: 110, width: 1220, height: 740), 28).fill()
NSColor(calibratedWhite: 1, alpha: 0.84).setFill()
rounded(NSRect(x: 96, y: 126, width: 1220, height: 740), 28).fill()

if let icon = NSImage(contentsOfFile: "Assets/AppIcon.png") {
    icon.draw(in: NSRect(x: 138, y: 780, width: 72, height: 72))
}
text("LivePhotoMaker", NSRect(x: 230, y: 808, width: 420, height: 36), size: 32, weight: .semibold)
text("批量把视频导入「照片」并识别为 Live Photo。", NSRect(x: 232, y: 780, width: 560, height: 24), size: 17, color: NSColor(calibratedWhite: 0.36, alpha: 1))
label("关于", x: 1010, y: 798, w: 112)
label("检查更新", x: 1140, y: 798, w: 132)

NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
rounded(NSRect(x: 136, y: 242, width: 720, height: 500), 18).fill()
rounded(NSRect(x: 886, y: 242, width: 360, height: 500), 18).fill()
rounded(NSRect(x: 136, y: 154, width: 1110, height: 64), 18).fill()

text("导入队列", NSRect(x: 166, y: 700, width: 180, height: 28), size: 20, weight: .semibold)
NSColor(calibratedWhite: 0.92, alpha: 1).setStroke()
let drop = rounded(NSRect(x: 166, y: 616, width: 660, height: 76), 14)
drop.lineWidth = 2
drop.stroke()
text("拖入视频   MP4, MOV, M4V", NSRect(x: 346, y: 642, width: 320, height: 24), size: 18, weight: .medium, alignment: .center)

for (index, name) in ["IMG_1042.MOV", "beach-live.mp4", "family-clip.mov"].enumerated() {
    let y = 538 - CGFloat(index) * 74
    NSColor(calibratedWhite: 1, alpha: 1).setFill()
    rounded(NSRect(x: 166, y: y, width: 660, height: 56), 12).fill()
    NSColor.systemBlue.setFill()
    rounded(NSRect(x: 184, y: y + 12, width: 32, height: 32), 8).fill()
    text(name, NSRect(x: 232, y: y + 27, width: 300, height: 20), size: 16, weight: .medium)
    text("/Users/me/Videos", NSRect(x: 232, y: y + 9, width: 300, height: 18), size: 12, color: NSColor(calibratedWhite: 0.36, alpha: 1))
    text("选择封面", NSRect(x: 676, y: y + 18, width: 90, height: 20), size: 13, color: NSColor(calibratedWhite: 0.36, alpha: 1), alignment: .right)
}

label("选择视频", x: 166, y: 276, w: 132)
label("清空", x: 316, y: 276, w: 90)

text("封面", NSRect(x: 916, y: 700, width: 120, height: 28), size: 20, weight: .semibold)
NSColor(calibratedWhite: 1, alpha: 1).setFill()
rounded(NSRect(x: 916, y: 554, width: 300, height: 120), 14).fill()
text("自动封面", NSRect(x: 940, y: 622, width: 180, height: 22), size: 16, weight: .medium)
text("未选择封面时，会使用视频中间帧。", NSRect(x: 940, y: 592, width: 230, height: 38), size: 13, color: NSColor(calibratedWhite: 0.36, alpha: 1))
label("选择图片", x: 916, y: 498, w: 126)
label("选帧", x: 1058, y: 498, w: 86)
label("重置", x: 1158, y: 498, w: 74)

text("导入位置", NSRect(x: 916, y: 422, width: 120, height: 24), size: 18, weight: .semibold)
text("照片 App", NSRect(x: 916, y: 386, width: 200, height: 28), size: 24, weight: .semibold)
text("每个视频都会作为 Live Photo 导入。", NSRect(x: 916, y: 354, width: 270, height: 22), size: 15, color: NSColor(calibratedWhite: 0.36, alpha: 1))
label("从视频选择封面", x: 916, y: 292, w: 220)
label("创建 Live Photo", x: 916, y: 238, w: 220)

text("3 个视频已准备好。", NSRect(x: 166, y: 176, width: 420, height: 22), size: 16, color: NSColor(calibratedWhite: 0.36, alpha: 1))
NSColor.systemBlue.setFill()
rounded(NSRect(x: 166, y: 166, width: 720, height: 8), 4).fill()
text("100%", NSRect(x: 1180, y: 174, width: 48, height: 20), size: 14, weight: .medium, color: NSColor(calibratedWhite: 0.36, alpha: 1), alignment: .right)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render screenshot")
}

let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: outputURL)
