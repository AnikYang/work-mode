import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func drawIcon(pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(pixels) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()
    let rect = NSRect(x: 82, y: 82, width: 860, height: 860)
    let background = NSBezierPath(roundedRect: rect, xRadius: 194, yRadius: 194)
    NSGradient(starting: NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.28, alpha: 1),
               ending: NSColor(calibratedRed: 0.91, green: 0.42, blue: 0.08, alpha: 1))!
        .draw(in: background, angle: -90)
    NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.91, alpha: 1).setStroke()
    let sun = NSBezierPath(ovalIn: NSRect(x: 389, y: 389, width: 246, height: 246))
    sun.lineWidth = 33
    sun.stroke()
    let rays = NSBezierPath()
    rays.lineWidth = 33
    rays.lineCapStyle = .round
    for index in 0..<8 {
        let angle = CGFloat(index) * .pi / 4
        rays.move(to: NSPoint(x: 512 + cos(angle) * 199, y: 512 + sin(angle) * 199))
        rays.line(to: NSPoint(x: 512 + cos(angle) * 255, y: 512 + sin(angle) * 255))
    }
    rays.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let suffix = factor == 2 ? "@2x" : ""
        try drawIcon(pixels: size * factor).write(to: destination.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
