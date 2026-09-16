// Renders the app icon to a 1024x1024 PNG. Usage: swift scripts/make-icon.swift out.png
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png")

let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// Work in a y-down coordinate system like a design tool.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

// macOS icon grid: 824pt squircle centered on a 1024 canvas.
let box = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = CGPath(roundedRect: box, cornerWidth: 186, cornerHeight: 186, transform: nil)

// Drop shadow.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: color(0x000000, 0.35))
ctx.addPath(squircle); ctx.setFillColor(color(0x1E9E6E)); ctx.fillPath()
ctx.restoreGState()

// Gradient fill.
ctx.saveGState()
ctx.addPath(squircle); ctx.clip()
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [color(0x4CE08A), color(0x14A07A), color(0x0B7F78)] as CFArray, locations: [0, 0.6, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: box.minX, y: box.minY), end: CGPoint(x: box.maxX, y: box.maxY), options: [])
// Soft highlight in the top-left.
let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                      colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 330, y: 260), startRadius: 0, endCenter: CGPoint(x: 330, y: 260), endRadius: 560, options: [])
ctx.restoreGState()

// Figure reaching up. Strokes with round caps, white, slight shadow for depth.
func stroke(_ points: [CGPoint], width: CGFloat) {
    ctx.beginPath()
    ctx.move(to: points[0])
    for p in points.dropFirst() { ctx.addLine(to: p) }
    ctx.setLineWidth(width); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.setStrokeColor(color(0xFFFFFF)); ctx.strokePath()
}

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: color(0x000000, 0.25))
let w: CGFloat = 66
let shoulder = CGPoint(x: 512, y: 448)
let hip = CGPoint(x: 512, y: 618)
stroke([shoulder, hip], width: w)                                            // torso
stroke([CGPoint(x: 372, y: 262), shoulder, CGPoint(x: 652, y: 262)], width: w) // arms in a V
stroke([CGPoint(x: 428, y: 800), hip, CGPoint(x: 596, y: 800)], width: w)     // legs
ctx.setFillColor(color(0xFFFFFF))
ctx.fillEllipse(in: CGRect(x: 512 - 70, y: 318 - 70, width: 140, height: 140)) // head
ctx.restoreGState()

// The goal: a star between the hands.
func star(center: CGPoint, outer: CGFloat, inner: CGFloat) -> CGPath {
    let path = CGMutablePath()
    for i in 0..<10 {
        let r = i.isMultiple(of: 2) ? outer : inner
        let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
        let p = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
        i == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    return path
}
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 16, color: color(0xFFD60A, 0.55))
ctx.addPath(star(center: CGPoint(x: 512, y: 168), outer: 60, inner: 26))
ctx.setFillColor(color(0xFFD60A)); ctx.fillPath()
ctx.restoreGState()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(out.path)")
