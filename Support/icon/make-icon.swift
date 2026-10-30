// Disegna l'icona "Tazzina verde" e crea AppIcon.icns.
// Uso: swift Support/icon/make-icon.swift Support/AppIcon.icns [anteprima.png]
//
// Il disegno usa una griglia di 100 unità (come la bozza SVG) mappata sulla forma
// standard delle icone macOS: 824 px dentro una tela di 1024, con ombra.

import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.icns")
let preview = CommandLine.arguments.dropFirst(2).first.map { URL(fileURLWithPath: $0) }

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func gradient(_ top: UInt32, _ bottom: UInt32) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(top), color(bottom)] as CFArray,
               locations: [0, 1])!
}

/// Disegna l'icona in un contesto di `size` px, con origine in alto a sinistra.
func drawIcon(in ctx: CGContext, size: CGFloat) {
    let px = size / 1024
    // Griglia 100 unità: la forma (6…94) occupa 824 px a partire da 100 px.
    let scale = 824 / 88 * px
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: (100 * px) + (x - 6) * scale, y: (100 * px) + (y - 6) * scale) }
    func u(_ v: CGFloat) -> CGFloat { v * scale }

    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    // Forma di base con ombra.
    let shape = CGPath(roundedRect: CGRect(origin: p(6, 6), size: CGSize(width: u(88), height: u(88))),
                       cornerWidth: u(20), cornerHeight: u(20), transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * px), blur: 24 * px, color: color(0x000000, 0.28))
    ctx.addPath(shape)
    ctx.setFillColor(color(0xF6E2C0))
    ctx.fillPath()
    ctx.restoreGState()

    // Sfondo crema con leggero gradiente.
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    ctx.drawLinearGradient(gradient(0xFDF5E8, 0xF4DDB6), start: p(50, 6), end: p(50, 94), options: [])
    ctx.restoreGState()

    // Vapore.
    ctx.setLineCap(.round)
    ctx.setStrokeColor(color(0xC8862A))
    ctx.setLineWidth(u(2.6))
    for x in [37.0, 47.0] as [CGFloat] {
        ctx.move(to: p(x, 32))
        ctx.addCurve(to: p(x, 18), control1: p(x - 5, 27), control2: p(x + 5, 23))
        ctx.strokePath()
    }

    // Piattino.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -3 * px), blur: 6 * px, color: color(0x633806, 0.25))
    ctx.addEllipse(in: CGRect(origin: p(17, 66), size: CGSize(width: u(54), height: u(10))))
    ctx.setFillColor(color(0xE4E0D6))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.addEllipse(in: CGRect(origin: p(27, 67.5), size: CGSize(width: u(34), height: u(5))))
    ctx.setFillColor(color(0xD3CEC2))
    ctx.fillPath()

    // Manico: cerchio dietro alla tazza, se ne vede solo la parte destra.
    ctx.setStrokeColor(color(0x854F0B))
    ctx.setLineWidth(u(3.6))
    ctx.addEllipse(in: CGRect(origin: p(58.5, 45.5), size: CGSize(width: u(15), height: u(15))))
    ctx.strokePath()

    // Corpo della tazza: rettangolo con fondo a semiellisse.
    let k: CGFloat = 0.5523
    let cup = CGMutablePath()
    cup.move(to: p(25, 40))
    cup.addLine(to: p(63, 40))
    cup.addLine(to: p(63, 50))
    cup.addCurve(to: p(44, 68), control1: p(63, 50 + 18 * k), control2: p(44 + 19 * k, 68))
    cup.addCurve(to: p(25, 50), control1: p(44 - 19 * k, 68), control2: p(25, 50 + 18 * k))
    cup.closeSubpath()
    ctx.saveGState()
    ctx.addPath(cup)
    ctx.clip()
    ctx.drawLinearGradient(gradient(0xFFFFFF, 0xEFEBE3), start: p(30, 40), end: p(58, 68), options: [])
    ctx.restoreGState()
    // Contorno aperto in alto (lo copre il caffè), con estremità arrotondate.
    let rim = CGMutablePath()
    rim.move(to: p(25, 40))
    rim.addLine(to: p(25, 50))
    rim.addCurve(to: p(44, 68), control1: p(25, 50 + 18 * k), control2: p(44 - 19 * k, 68))
    rim.addCurve(to: p(63, 50), control1: p(44 + 19 * k, 68), control2: p(63, 50 + 18 * k))
    rim.addLine(to: p(63, 40))
    ctx.addPath(rim)
    ctx.setStrokeColor(color(0x854F0B))
    ctx.setLineWidth(u(2.6))
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    // Caffè.
    ctx.addEllipse(in: CGRect(origin: p(25.5, 36.6), size: CGSize(width: u(37), height: u(6.8))))
    ctx.setFillColor(color(0x633806))
    ctx.fillPath()
    ctx.addEllipse(in: CGRect(origin: p(32, 37.6), size: CGSize(width: u(14), height: u(2.4))))
    ctx.setFillColor(color(0x8A5A2B))
    ctx.fillPath()

    // Pallino verde con spunta.
    let badge = CGRect(origin: p(60, 58), size: CGSize(width: u(26), height: u(26)))
    ctx.addEllipse(in: badge.insetBy(dx: -u(2.6), dy: -u(2.6)))
    ctx.setFillColor(color(0xFAEBD2))
    ctx.fillPath()
    ctx.saveGState()
    ctx.addEllipse(in: badge)
    ctx.clip()
    ctx.drawLinearGradient(gradient(0x7DB52F, 0x4F8A17), start: p(73, 58), end: p(73, 84), options: [])
    ctx.restoreGState()
    ctx.setStrokeColor(color(0xFFFFFF))
    ctx.setLineWidth(u(3.4))
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: p(66.5, 71))
    ctx.addLine(to: p(71, 75.5))
    ctx.addLine(to: p(79.5, 67))
    ctx.strokePath()
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    drawIcon(in: context.cgContext, size: CGFloat(size))
    context.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

// Iconset con tutte le dimensioni richieste da macOS, poi iconutil.
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try png(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
if let preview {
    try png(size: 1024).write(to: preview)
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { fatalError("iconutil non riuscito") }
print("Icona creata: \(output.path)")
