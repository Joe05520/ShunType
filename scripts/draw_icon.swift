import AppKit
import Foundation

let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
func draw(_ side: Int) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(side) / 1024
    NSGraphicsContext.current!.cgContext.scaleBy(x: scale, y: scale)
    NSColor.clear.setFill(); NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
    let rect = NSRect(x: 76, y: 76, width: 872, height: 872)
    let path = NSBezierPath(roundedRect: rect, xRadius: 200, yRadius: 200)
    NSGradient(starting: NSColor(calibratedRed: 0.12, green: 0.59, blue: 0.49, alpha: 1), ending: NSColor(calibratedRed: 0.03, green: 0.29, blue: 0.28, alpha: 1))!.draw(in: path, angle: -70)
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 500, weight: .medium), .foregroundColor: NSColor.white]
    let text = "順" as NSString
    let size = text.size(withAttributes: attrs)
    text.draw(at: NSPoint(x: (1024 - size.width)/2 - 8, y: (1024-size.height)/2 + 25), withAttributes: attrs)
    let line = NSBezierPath(roundedRect: NSRect(x: 300, y: 200, width: 424, height: 31), xRadius: 15, yRadius: 15)
    NSColor(calibratedRed: 0.68, green: 0.94, blue: 0.78, alpha: 1).setFill(); line.fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}
for size in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let bitmap = draw(size * factor)
        let suffix = factor == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
let bitmap = draw(32)
try bitmap.representation(using: .tiff, properties: [:])!.write(to: folder.deletingLastPathComponent().appendingPathComponent("InputMenu.tiff"))
