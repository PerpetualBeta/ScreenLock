#!/usr/bin/env swift
import AppKit

// Draws the ScreenLock icon: a monitor/display with a lock symbol, on brand-blue background.
// CG coordinate origin: bottom-left.
func drawIcon(ctx: CGContext, s: CGFloat) {
    let cs = CGColorSpaceCreateDeviceRGB()

    // ── 1. Background: brand blue gradient rounded rect ──────────────────────
    let bgRadius = s * 0.22
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                        cornerWidth: bgRadius, cornerHeight: bgRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let bgGrad = CGGradient(
        colorsSpace: cs,
        colors: [CGColor(red: 0.05, green: 0.32, blue: 0.58, alpha: 1),
                 CGColor(red: 0.00, green: 0.25, blue: 0.50, alpha: 1)] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(bgGrad,
                           start: CGPoint(x: s / 2, y: s),
                           end:   CGPoint(x: s / 2, y: 0),
                           options: [])
    ctx.restoreGState()

    // ── 2. Monitor body ──────────────────────────────────────────────────────
    let cx = s / 2
    let monW = s * 0.64
    let monH = s * 0.44
    let monX = cx - monW / 2
    let monY = s * 0.30
    let monR = s * 0.04

    // Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.02),
                  blur: s * 0.04,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))

    let monPath = CGPath(roundedRect: CGRect(x: monX, y: monY, width: monW, height: monH),
                         cornerWidth: monR, cornerHeight: monR, transform: nil)
    ctx.setFillColor(CGColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1))
    ctx.addPath(monPath)
    ctx.fillPath()
    ctx.restoreGState()

    // Screen area (slightly inset)
    let scrInset = s * 0.025
    let scrX = monX + scrInset
    let scrY = monY + scrInset
    let scrW = monW - scrInset * 2
    let scrH = monH - scrInset * 2
    let scrR = s * 0.02

    let scrPath = CGPath(roundedRect: CGRect(x: scrX, y: scrY, width: scrW, height: scrH),
                         cornerWidth: scrR, cornerHeight: scrR, transform: nil)
    ctx.saveGState()
    ctx.addPath(scrPath)
    ctx.clip()
    let scrGrad = CGGradient(
        colorsSpace: cs,
        colors: [CGColor(red: 0.15, green: 0.38, blue: 0.65, alpha: 1),
                 CGColor(red: 0.08, green: 0.28, blue: 0.52, alpha: 1)] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(scrGrad,
                           start: CGPoint(x: cx, y: scrY + scrH),
                           end:   CGPoint(x: cx, y: scrY),
                           options: [])
    ctx.restoreGState()

    // Stand
    let standW = s * 0.12
    let standH = s * 0.08
    let standX = cx - standW / 2
    let standY = monY - standH
    ctx.setFillColor(CGColor(red: 0.22, green: 0.22, blue: 0.26, alpha: 1))
    ctx.fill(CGRect(x: standX, y: standY, width: standW, height: standH))

    // Base
    let baseW = s * 0.24
    let baseH = s * 0.025
    let baseX = cx - baseW / 2
    let baseY = standY - baseH
    let basePath = CGPath(roundedRect: CGRect(x: baseX, y: baseY, width: baseW, height: baseH),
                          cornerWidth: baseH / 2, cornerHeight: baseH / 2, transform: nil)
    ctx.setFillColor(CGColor(red: 0.25, green: 0.25, blue: 0.30, alpha: 1))
    ctx.addPath(basePath)
    ctx.fillPath()

    // ── 3. Lock icon on screen ───────────────────────────────────────────────
    let lockColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.95)
    let lockCX = cx
    let lockCY = monY + monH * 0.48

    // Lock body (rounded rect)
    let lockW = s * 0.13
    let lockH = s * 0.10
    let lockX = lockCX - lockW / 2
    let lockY = lockCY - lockH / 2 - s * 0.02
    let lockR = s * 0.02

    ctx.setFillColor(lockColor)
    let lockPath = CGPath(roundedRect: CGRect(x: lockX, y: lockY, width: lockW, height: lockH),
                          cornerWidth: lockR, cornerHeight: lockR, transform: nil)
    ctx.addPath(lockPath)
    ctx.fillPath()

    // Lock shackle (arc above the body)
    let shackleR = lockW * 0.34
    let shackleY = lockY + lockH
    ctx.setStrokeColor(lockColor)
    ctx.setLineWidth(s * 0.025)
    ctx.setLineCap(.round)
    ctx.addArc(center: CGPoint(x: lockCX, y: shackleY),
               radius: shackleR,
               startAngle: 0,
               endAngle: .pi,
               clockwise: false)
    ctx.strokePath()

    // Keyhole
    let holeR = s * 0.015
    let holeY = lockY + lockH * 0.55
    ctx.setFillColor(CGColor(red: 0.08, green: 0.28, blue: 0.52, alpha: 1))
    ctx.addEllipse(in: CGRect(x: lockCX - holeR, y: holeY - holeR, width: holeR * 2, height: holeR * 2))
    ctx.fillPath()
}

// ── Render at given pixel size ───────────────────────────────────────────────
func renderIcon(pixels: Int) -> Data? {
    guard let bmp = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: NSColorSpaceName.deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    else { return nil }

    guard let ctx = NSGraphicsContext(bitmapImageRep: bmp)?.cgContext else { return nil }
    drawIcon(ctx: ctx, s: CGFloat(pixels))
    return bmp.representation(using: NSBitmapImageRep.FileType.png, properties: [:])
}

// ── Main ─────────────────────────────────────────────────────────────────────
let destDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath

let sizes: [(String, Int)] = [
    ("icon_16x16.png",      16),
    ("icon_16x16@2x.png",   32),
    ("icon_32x32.png",      32),
    ("icon_32x32@2x.png",   64),
    ("icon_128x128.png",   128),
    ("icon_128x128@2x.png",256),
    ("icon_256x256.png",   256),
    ("icon_256x256@2x.png",512),
    ("icon_512x512.png",   512),
    ("icon_512x512@2x.png",1024),
]

for (filename, pixels) in sizes {
    if let data = renderIcon(pixels: pixels) {
        let url = URL(fileURLWithPath: destDir).appendingPathComponent(filename)
        try! data.write(to: url)
        print("✓  \(filename)  (\(pixels)px)")
    } else {
        print("✗  Failed: \(filename)")
    }
}
print("Done.")
