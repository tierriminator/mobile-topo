// Renders the app icons for every platform from assets/logo.
//
// Run on macOS with: mise run icons
//
// background.svg and foreground.svg are 1024x1024 layers. The foreground
// keeps to the centre that Android's adaptive icon masks always show; the
// other platforms are zoomed in to match.

import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func loadSVG(_ name: String) -> NSImage {
    let url = root.appendingPathComponent("assets/logo/\(name)")
    guard let image = NSImage(contentsOf: url) else {
        fatalError("Cannot load \(url.path)")
    }
    return image
}

let background = loadSVG("background.svg")
let foreground = loadSVG("foreground.svg")

enum Shape {
    /// Full bleed square, without alpha (iOS rejects icons with alpha).
    case opaqueSquare
    /// Full bleed square with alpha.
    case square
    /// Rounded square inset into the canvas, as macOS and Android legacy
    /// icons are drawn. Fractions are of the canvas size.
    case roundedSquare(inset: CGFloat, radius: CGFloat, shadow: Bool)
}

/// Icons that no system masks show the layers as Android's masks do: only
/// the central 72dp of the 108dp layers.
let unmasked: CGFloat = 108 / 72

func render(_ layers: [NSImage], size: Int, shape: Shape, zoom: CGFloat = unmasked) -> Data {
    let alpha: CGImageAlphaInfo
    if case .opaqueSquare = shape { alpha = .noneSkipLast } else { alpha = .premultipliedLast }
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: alpha.rawValue)!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current!.imageInterpolation = .high

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    var rect = canvas
    if case let .roundedSquare(inset, radius, shadow) = shape {
        let s = CGFloat(size)
        rect = canvas.insetBy(dx: s * inset, dy: s * inset)
        let path = NSBezierPath(roundedRect: rect, xRadius: s * radius,
                                yRadius: s * radius)
        if shadow {
            NSGraphicsContext.saveGraphicsState()
            let drop = NSShadow()
            drop.shadowColor = NSColor.black.withAlphaComponent(0.3)
            drop.shadowOffset = NSSize(width: 0, height: -s * 0.01)
            drop.shadowBlurRadius = s * 0.02
            drop.set()
            NSColor.black.setFill()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        path.addClip()
    }
    let grow = rect.width * (zoom - 1) / 2
    for layer in layers {
        layer.draw(in: rect.insetBy(dx: -grow, dy: -grow), from: .zero,
                   operation: .sourceOver, fraction: 1)
    }

    NSGraphicsContext.restoreGraphicsState()
    let png = NSMutableData()
    let destination = CGImageDestinationCreateWithData(png, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
    return png as Data
}

func write(_ data: Data, _ path: String) {
    let url = root.appendingPathComponent(path)
    try! FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! data.write(to: url)
    print(path)
}

let both = [background, foreground]

// iOS: the system applies the rounded mask.
for (points, scales) in [(20.0, [1, 2, 3]), (29, [1, 2, 3]), (40, [1, 2, 3]),
                         (60, [2, 3]), (76, [1, 2]), (83.5, [2]), (1024, [1])] {
    for scale in scales {
        let name = points == 83.5 ? "83.5" : String(Int(points))
        write(render(both, size: Int(points * Double(scale)), shape: .opaqueSquare),
              "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-\(name)x\(name)@\(scale)x.png")
    }
}

// macOS: Apple's icon grid puts an 824 point rounded square on a 1024 canvas.
for size in [16, 32, 64, 128, 256, 512, 1024] {
    write(render(both, size: size,
                 shape: .roundedSquare(inset: 100 / 1024, radius: 185.4 / 1024, shadow: true)),
          "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_\(size).png")
}

// Android: adaptive icon layers at 108dp, legacy icons at 48dp.
let densities = [("mdpi", 1.0), ("hdpi", 1.5), ("xhdpi", 2.0), ("xxhdpi", 3.0), ("xxxhdpi", 4.0)]
for (density, factor) in densities {
    let dir = "android/app/src/main/res/mipmap-\(density)"
    let layer = Int(108 * factor)
    write(render([background], size: layer, shape: .square, zoom: 1),
          "\(dir)/ic_launcher_background.png")
    write(render([foreground], size: layer, shape: .square, zoom: 1),
          "\(dir)/ic_launcher_foreground.png")
    write(render(both, size: Int(48 * factor),
                 shape: .roundedSquare(inset: 2 / 48, radius: 8 / 48, shadow: false)),
          "\(dir)/ic_launcher.png")
}

// Web.
write(render(both, size: 16, shape: .square), "web/favicon.png")
for size in [192, 512] {
    write(render(both, size: size,
                 shape: .roundedSquare(inset: 0, radius: 0.18, shadow: false)),
          "web/icons/Icon-\(size).png")
    write(render(both, size: size, shape: .square, zoom: 1),
          "web/icons/Icon-maskable-\(size).png")
}
