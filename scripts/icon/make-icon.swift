#!/usr/bin/env swift
//
// Renders the Ametrine icon: the faceted gem of gem-source.png, keeping its
// facet shading, coloured from purple (amethyst) to gold (citrine) along a
// gradient. CoreGraphics only, nothing to install.
//
// Usage: swift scripts/icon/make-icon.swift [--angle <degrees>] [--blend <0-1>] [--out <dir>]
//
//   --angle  direction of the gradient, from purple to gold: 90 = top to
//            bottom (default), 45 = top left to bottom right
//   --blend  width of the purple-to-gold transition, 0 = a sharp line,
//            1 = the whole icon (default 0.5)
//   --out    directory for a preview (ametrine.png, 1024 px) instead of
//            writing the asset catalog
//
// Without --out it writes every size of AppIcon.appiconset and the layout
// HUD's amethyst.imageset.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct RGB {
    var r: Double, g: Double, b: Double

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    func mixed(with other: RGB, _ t: Double) -> RGB {
        return RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }
}

/// Dark, mid and light tone of a stone; a pixel's luminance picks a point on it.
struct Ramp {
    let dark: RGB, mid: RGB, light: RGB

    func color(at luminance: Double) -> RGB {
        return luminance < 0.5
            ? dark.mixed(with: mid, luminance * 2)
            : mid.mixed(with: light, (luminance - 0.5) * 2)
    }
}

let amethyst = Ramp(dark: RGB(0x2A0B4F), mid: RGB(0x8A3FD1), light: RGB(0xEBD3FF))
let citrine = Ramp(dark: RGB(0xB06A00), mid: RGB(0xF5B82E), light: RGB(0xFFF4C4))
// Passing through rose keeps the transition from turning grey, as purple and gold would mixed directly.
let rose = Ramp(dark: RGB(0x6A1846), mid: RGB(0xD9578E), light: RGB(0xFFD6E4))

var angle = 90.0
var blend = 0.5
var outDirectory: String?

var arguments = CommandLine.arguments.dropFirst().makeIterator()
while let argument = arguments.next() {
    switch argument {
    case "--angle": angle = Double(arguments.next() ?? "") ?? angle
    case "--blend": blend = Double(arguments.next() ?? "") ?? blend
    case "--out": outDirectory = arguments.next()
    default:
        FileHandle.standardError.write("unknown argument: \(argument)\n".data(using: .utf8)!)
        exit(2)
    }
}

let scriptDirectory = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let repoRoot = scriptDirectory.deletingLastPathComponent().deletingLastPathComponent()
let assets = repoRoot.appendingPathComponent("Amethyst/Images.xcassets")

func loadImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fatalError("can't read \(url.path)")
    }
    return image
}

func bitmap(width: Int, height: Int) -> CGContext {
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    guard edge1 > edge0 else { return x < edge0 ? 0 : 1 }
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}

/// The gem, recoloured at the source's full size.
func render(_ source: CGImage) -> CGImage {
    let width = source.width, height = source.height
    let context = bitmap(width: width, height: height)
    context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    let pixels = context.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)

    func luminance(_ i: Int) -> Double? {
        let a = Double(pixels[i + 3])
        guard a > 0 else { return nil }
        let r = Double(pixels[i]) / a, g = Double(pixels[i + 1]) / a, b = Double(pixels[i + 2]) / a
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    // Stretch the source's luminance to 0…1 so both stones use their whole ramp.
    var low = 1.0, high = 0.0
    for i in stride(from: 0, to: width * height * 4, by: 4) {
        if let l = luminance(i), pixels[i + 3] > 200 {
            low = min(low, l)
            high = max(high, l)
        }
    }

    let radians = angle * .pi / 180
    let dx = cos(radians), dy = sin(radians)
    // Project the corners to get the gradient's extent along its direction.
    let corners = [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)].map { $0.0 * dx + $0.1 * dy }
    let start = corners.min()!, end = corners.max()!

    for y in 0..<height {
        for x in 0..<width {
            let i = (y * width + x) * 4
            guard let l = luminance(i) else { continue }
            let tone = min(max((l - low) / max(high - low, 0.001), 0), 1)
            // Image rows run top to bottom, so y grows downwards: 45° = top left to bottom right.
            let position = ((Double(x) / Double(width)) * dx + (Double(y) / Double(height)) * dy - start) / (end - start)
            let t = smoothstep(0.5 - blend / 2, 0.5 + blend / 2, position)
            let color = t < 0.5
                ? amethyst.color(at: tone).mixed(with: rose.color(at: tone), t * 2)
                : rose.color(at: tone).mixed(with: citrine.color(at: tone), (t - 0.5) * 2)
            let a = Double(pixels[i + 3])
            pixels[i] = UInt8(min(color.r * a, 255))
            pixels[i + 1] = UInt8(min(color.g * a, 255))
            pixels[i + 2] = UInt8(min(color.b * a, 255))
        }
    }

    return context.makeImage()!
}

func scaled(_ image: CGImage, to size: Int) -> CGImage {
    let context = bitmap(width: size, height: size)
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("can't write \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("can't write \(url.path)")
    }
    print("wrote \(url.path)")
}

let icon = render(loadImage(scriptDirectory.appendingPathComponent("gem-source.png")))

if let outDirectory = outDirectory {
    let directory = URL(fileURLWithPath: outDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    write(icon, to: directory.appendingPathComponent("ametrine.png"))
    exit(0)
}

for size in [16, 32, 128, 256, 512] {
    let appIcon = assets.appendingPathComponent("AppIcon.appiconset")
    write(scaled(icon, to: size), to: appIcon.appendingPathComponent("icon_\(size)x\(size).png"))
    write(scaled(icon, to: size * 2), to: appIcon.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let hudIcon = assets.appendingPathComponent("amethyst.imageset")
write(scaled(icon, to: 32), to: hudIcon.appendingPathComponent("icon_32x32.png"))
write(scaled(icon, to: 64), to: hudIcon.appendingPathComponent("icon_32x32@2x.png"))
