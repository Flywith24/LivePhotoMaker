import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: swift remove_black_background.swift input.png output.png")
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let sourceImage = NSImage(contentsOf: inputURL),
      let tiff = sourceImage.tiffRepresentation,
      let source = NSBitmapImageRep(data: tiff),
      let output = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: source.pixelsWide,
        pixelsHigh: source.pixelsHigh,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
      ) else {
    fatalError("Could not read input image")
}

for y in 0..<source.pixelsHigh {
    for x in 0..<source.pixelsWide {
        guard let color = source.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
            continue
        }

        let brightness = max(color.redComponent, color.greenComponent, color.blueComponent)
        let alpha: CGFloat
        if brightness < 0.025 {
            alpha = 0
        } else if brightness < 0.10 {
            alpha = (brightness - 0.025) / 0.075
        } else {
            alpha = 1
        }

        output.setColor(
            NSColor(
                deviceRed: color.redComponent,
                green: color.greenComponent,
                blue: color.blueComponent,
                alpha: alpha
            ),
            atX: x,
            y: y
        )
    }
}

guard let png = output.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode output image")
}

try png.write(to: outputURL)
