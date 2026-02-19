#!/usr/bin/swift
// Generates GuitarApp.icns — a waveform icon.
// Run: swift make_icon.swift

import Cocoa
import CoreGraphics

// MARK: - Draw the icon into a CGContext at a given size

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = size

    // --- Background: dark rounded rectangle ---
    let bg = CGRect(x: 0, y: 0, width: s, height: s)
    let radius = s * 0.22
    let bgPath = CGPath(roundedRect: bg, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Deep dark gradient
    ctx.addPath(bgPath)
    ctx.clip()

    let colors = [
        CGColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1),
        CGColor(red: 0.13, green: 0.13, blue: 0.20, alpha: 1)
    ] as CFArray
    let locs: [CGFloat] = [0, 1]
    let space = CGColorSpaceCreateDeviceRGB()
    if let grad = CGGradient(colorsSpace: space, colors: colors, locations: locs) {
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: s * 0.5, y: s),
                               end:   CGPoint(x: s * 0.5, y: 0),
                               options: [])
    }
    ctx.resetClip()

    // --- Subtle inner glow ring ---
    ctx.addPath(bgPath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.06))
    ctx.setLineWidth(s * 0.015)
    ctx.strokePath()

    // --- Waveform bars ---
    // Amplitudes (mirrored top/bottom, center-symmetric)
    // These approximate a guitar-like waveform shape
    let amplitudes: [CGFloat] = [
        0.10, 0.18, 0.30, 0.50, 0.72, 0.88, 0.95, 1.00,
        0.90, 0.70, 0.82, 0.95, 0.80, 0.60, 0.40, 0.28,
        0.38, 0.55, 0.70, 0.60, 0.45, 0.30, 0.18, 0.10
    ]

    let barCount = amplitudes.count
    let margin = s * 0.14
    let totalWidth = s - margin * 2
    let barSpacing: CGFloat = totalWidth / CGFloat(barCount)
    let barWidth = barSpacing * 0.55
    let maxHalfHeight = s * 0.36   // max half-height of a bar
    let centerY = s * 0.5

    for i in 0..<barCount {
        let amp = amplitudes[i]
        let halfH = amp * maxHalfHeight
        let x = margin + CGFloat(i) * barSpacing + (barSpacing - barWidth) / 2
        let barRect = CGRect(x: x, y: centerY - halfH, width: barWidth, height: halfH * 2)
        let barRadius = barWidth * 0.5  // fully pill-shaped

        // Shadow / glow behind bar
        ctx.setShadow(offset: .zero,
                      blur: s * 0.03,
                      color: CGColor(red: 0.35, green: 0.65, blue: 1.0, alpha: 0.45))

        // Bar gradient: bright blue-white at peak, deeper blue at center
        let barPath = CGPath(roundedRect: barRect, cornerWidth: barRadius, cornerHeight: barRadius, transform: nil)
        ctx.addPath(barPath)
        ctx.clip()

        let barColors = [
            CGColor(red: 0.55, green: 0.82, blue: 1.00, alpha: 1.0),  // top highlight
            CGColor(red: 0.30, green: 0.60, blue: 1.00, alpha: 1.0),  // mid blue
            CGColor(red: 0.20, green: 0.45, blue: 0.90, alpha: 1.0),  // bottom
        ] as CFArray
        let barLocs: [CGFloat] = [0, 0.5, 1]
        if let barGrad = CGGradient(colorsSpace: space, colors: barColors, locations: barLocs) {
            ctx.drawLinearGradient(barGrad,
                                   start: CGPoint(x: x + barWidth / 2, y: centerY + halfH),
                                   end:   CGPoint(x: x + barWidth / 2, y: centerY - halfH),
                                   options: [])
        }
        ctx.resetClip()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
    }

    // --- Center line ---
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
    ctx.setLineWidth(s * 0.008)
    ctx.move(to: CGPoint(x: margin, y: centerY))
    ctx.addLine(to: CGPoint(x: s - margin, y: centerY))
    ctx.strokePath()

    image.unlockFocus()
    return image
}

// MARK: - Write PNG at a given size into an iconset folder

func writePNG(_ image: NSImage, to url: URL) {
    guard let tiff = image.tiffRepresentation,
          let bmp = NSBitmapImageRep(data: tiff),
          let png = bmp.representation(using: .png, properties: [:]) else {
        print("Failed to encode PNG for \(url.lastPathComponent)")
        return
    }
    try? png.write(to: url)
}

// MARK: - Main

let fm = FileManager.default
let projectDir = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath)

let iconsetDir = projectDir.appendingPathComponent("AppIcon.iconset")
try? fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

// Required iconset entries for a macOS .icns
let sizes: [(name: String, pts: CGFloat, scale: Int)] = [
    ("icon_16x16",      16,  1),
    ("icon_16x16@2x",   16,  2),
    ("icon_32x32",      32,  1),
    ("icon_32x32@2x",   32,  2),
    ("icon_128x128",   128,  1),
    ("icon_128x128@2x",128,  2),
    ("icon_256x256",   256,  1),
    ("icon_256x256@2x",256,  2),
    ("icon_512x512",   512,  1),
    ("icon_512x512@2x",512,  2),
]

for entry in sizes {
    let px = entry.pts * CGFloat(entry.scale)
    let img = drawIcon(size: px)
    let file = iconsetDir.appendingPathComponent("\(entry.name).png")
    writePNG(img, to: file)
    print("  wrote \(file.lastPathComponent) (\(Int(px))px)")
}

// Convert iconset → .icns using iconutil
let icnsURL = projectDir.appendingPathComponent("AppIcon.icns")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
try proc.run()
proc.waitUntilExit()

if proc.terminationStatus == 0 {
    print("✓ AppIcon.icns written to \(icnsURL.path)")
    // Clean up iconset
    try? fm.removeItem(at: iconsetDir)
} else {
    print("✗ iconutil failed (status \(proc.terminationStatus))")
}
