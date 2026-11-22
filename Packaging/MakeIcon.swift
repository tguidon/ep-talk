import AppKit

let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let context = NSGraphicsContext.current!.cgContext

func rounded(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ radius: CGFloat, _ color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius).fill()
}

rounded(78, 78, 868, 868, 186, NSColor(srgbRed: 0.094, green: 0.118, blue: 0.141, alpha: 1))
rounded(141, 141, 742, 742, 133, NSColor(srgbRed: 0.196, green: 0.231, blue: 0.263, alpha: 1))
rounded(150, 150, 724, 724, 127, NSColor(srgbRed: 0.051, green: 0.071, blue: 0.086, alpha: 1))
let mint = NSColor(srgbRed: 0.61, green: 0.85, blue: 0.75, alpha: 1)
let amber = NSColor(srgbRed: 1, green: 0.72, blue: 0.44, alpha: 1)

for (index, height) in [94, 184, 342, 244, 132].enumerated() {
    rounded(290 + CGFloat(index) * 88, 492 - CGFloat(height) / 2, 48, CGFloat(height), 24, mint)
}
context.setFillColor(amber.cgColor)
context.fillEllipse(in: CGRect(x: 738, y: 728, width: 55, height: 55))

NSGraphicsContext.restoreGraphicsState()
let icon = bitmap.cgImage!

func encodedLength(_ number: Int) -> Data {
    var bigEndian = UInt32(number).bigEndian
    return withUnsafeBytes(of: &bigEndian) { Data($0) }
}

var chunks = Data()
for (size, identifier) in [(16, "icp4"), (32, "icp5"), (64, "icp6"), (128, "ic07"),
                           (256, "ic08"), (512, "ic09"), (1024, "ic10")] {
    let resized = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    resized.interpolationQuality = .high
    resized.draw(icon, in: CGRect(x: 0, y: 0, width: size, height: size))
    let png = NSBitmapImageRep(cgImage: resized.makeImage()!).representation(using: .png, properties: [:])!
    chunks += Data(identifier.utf8) + encodedLength(png.count + 8) + png
}
let file = Data("icns".utf8) + encodedLength(chunks.count + 8) + chunks
try file.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
