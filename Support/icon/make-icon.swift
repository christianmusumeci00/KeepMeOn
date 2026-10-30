// Disegna l'icona "Tazzina verde" e crea le icone per Mac e Windows.
// Uso, dalla cartella del progetto: swift Support/icon/make-icon.swift [--preview anteprima.png]
//   Support/AppIcon.icns                          icona dell'app per macOS
//   windows/src/KeepMeOn/Resources/AppIcon.ico    icona dell'app per Windows
//   windows/src/KeepMeOn/Resources/Tray*.ico      icone dell'area di notifica (con spunta, in pausa, spenta)
//
// Il disegno usa una griglia di 100 unità (come la bozza SVG). Su macOS la forma occupa
// 824 px dentro una tela di 1024, con ombra; su Windows riempie quasi tutta la tela.

import AppKit

let icnsOutput = URL(fileURLWithPath: "Support/AppIcon.icns")
let windowsResources = URL(fileURLWithPath: "windows/src/KeepMeOn/Resources")
let preview = CommandLine.arguments.firstIndex(of: "--preview")
    .flatMap { CommandLine.arguments.indices.contains($0 + 1) ? URL(fileURLWithPath: CommandLine.arguments[$0 + 1]) : nil }

enum IconStyle {
    case mac
    case windows

    /// Margine attorno alla forma, in px su una tela di 1024.
    var margin: CGFloat { self == .mac ? 100 : 24 }
}

enum TrayVariant {
    case covering, paused, off
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func gradient(_ top: UInt32, _ bottom: UInt32) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(top), color(bottom)] as CFArray,
               locations: [0, 1])!
}

/// Disegna l'icona in un contesto di `size` px, con origine in alto a sinistra.
func drawIcon(in ctx: CGContext, size: CGFloat, style: IconStyle = .mac) {
    let px = size / 1024
    // Griglia 100 unità: la forma (6…94) occupa la tela meno i margini.
    let margin = style.margin
    let scale = (1024 - 2 * margin) / 88 * px
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: (margin * px) + (x - 6) * scale, y: (margin * px) + (y - 6) * scale) }
    func u(_ v: CGFloat) -> CGFloat { v * scale }

    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    // Forma di base con ombra (più leggera su Windows, dove il margine è stretto).
    let shape = CGPath(roundedRect: CGRect(origin: p(6, 6), size: CGSize(width: u(88), height: u(88))),
                       cornerWidth: u(20), cornerHeight: u(20), transform: nil)
    ctx.saveGState()
    if style == .mac {
        ctx.setShadow(offset: CGSize(width: 0, height: -10 * px), blur: 24 * px, color: color(0x000000, 0.28))
    } else {
        ctx.setShadow(offset: CGSize(width: 0, height: -4 * px), blur: 10 * px, color: color(0x000000, 0.22))
    }
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

/// Icona dell'area di notifica di Windows: solo tazzina e piattino, senza sfondo, con tratti
/// spessi per restare leggibile a 16 px. Disegno in una griglia di 100 unità.
func drawTrayIcon(in ctx: CGContext, size: CGFloat, variant: TrayVariant) {
    let s = size / 100
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
    func u(_ v: CGFloat) -> CGFloat { v * s }

    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    let isOff = variant == .off
    let outline = isOff ? color(0x8C8C8C) : color(0x7A4A0E)
    let line = u(7)

    // Piattino.
    ctx.addEllipse(in: CGRect(x: u(4), y: u(65), width: u(68), height: u(14)))
    ctx.setFillColor(isOff ? color(0xBDBDBD) : color(0xD9D2C4))
    ctx.fillPath()

    // Manico: cerchio dietro alla tazza.
    ctx.setStrokeColor(outline)
    ctx.setLineWidth(line)
    ctx.addEllipse(in: CGRect(x: u(55), y: u(31), width: u(22), height: u(22)))
    ctx.strokePath()

    // Corpo della tazza.
    let k: CGFloat = 0.5523
    let cup = CGMutablePath()
    cup.move(to: p(12, 24))
    cup.addLine(to: p(64, 24))
    cup.addLine(to: p(64, 38))
    cup.addCurve(to: p(38, 64), control1: p(64, 38 + 26 * k), control2: p(38 + 26 * k, 64))
    cup.addCurve(to: p(12, 38), control1: p(38 - 26 * k, 64), control2: p(12, 38 + 26 * k))
    cup.closeSubpath()
    ctx.addPath(cup)
    ctx.setFillColor(isOff ? color(0xE4E4E4) : color(0xFFFFFF))
    ctx.fillPath()
    ctx.addPath(cup)
    ctx.setStrokeColor(outline)
    ctx.setLineWidth(line)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    // Caffè.
    ctx.addEllipse(in: CGRect(x: u(14), y: u(19), width: u(48), height: u(10)))
    ctx.setFillColor(isOff ? color(0xA6A6A6) : color(0x633806))
    ctx.fillPath()

    guard variant == .covering else { return }

    // Ritaglio trasparente e pallino verde con spunta, come nella barra dei menu del Mac.
    let badge = CGRect(x: u(59), y: u(59), width: u(38), height: u(38))
    ctx.setBlendMode(.clear)
    ctx.addEllipse(in: badge.insetBy(dx: -u(5), dy: -u(5)))
    ctx.fillPath()
    ctx.setBlendMode(.normal)
    ctx.addEllipse(in: badge)
    ctx.setFillColor(color(0x4F9A1E))
    ctx.fillPath()
    ctx.setStrokeColor(color(0xFFFFFF))
    ctx.setLineWidth(u(6.5))
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: p(68, 78))
    ctx.addLine(to: p(75, 85))
    ctx.addLine(to: p(88, 71))
    ctx.strokePath()
}

func bitmap(size: Int, draw: (CGContext, CGFloat) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    draw(context.cgContext, CGFloat(size))
    context.flushGraphics()
    return rep
}

func png(size: Int, draw: (CGContext, CGFloat) -> Void = { drawIcon(in: $0, size: $1) }) -> Data {
    bitmap(size: size, draw: draw).representation(using: .png, properties: [:])!
}

/// Scrittura in little endian per i formati di Windows.
struct LittleEndianWriter {
    var data = Data()
    mutating func u8(_ value: Int) { data.append(UInt8(value)) }
    mutating func u16(_ value: Int) { withUnsafeBytes(of: UInt16(value).littleEndian) { data.append(contentsOf: $0) } }
    mutating func u32(_ value: Int) { withUnsafeBytes(of: UInt32(value).littleEndian) { data.append(contentsOf: $0) } }
}

/// Immagine in formato DIB a 32 bit (con maschera), come la vuole un file .ico per le dimensioni piccole.
func dib(_ rep: NSBitmapImageRep) -> Data {
    let width = rep.pixelsWide, height = rep.pixelsHigh
    let maskRowBytes = ((width + 31) / 32) * 4
    var out = LittleEndianWriter()
    // BITMAPINFOHEADER: l'altezza è doppia perché comprende la maschera.
    out.u32(40); out.u32(width); out.u32(height * 2); out.u16(1); out.u16(32); out.u32(0)
    out.u32(width * height * 4 + maskRowBytes * height); out.u32(0); out.u32(0); out.u32(0); out.u32(0)

    let pixels = rep.bitmapData!
    let rowBytes = rep.bytesPerRow
    // Righe dal basso verso l'alto, BGRA con alfa non premoltiplicato.
    for y in (0..<height).reversed() {
        for x in 0..<width {
            let i = y * rowBytes + x * 4
            let alpha = Int(pixels[i + 3])
            func straight(_ value: UInt8) -> Int { alpha == 0 ? 0 : min(255, Int(value) * 255 / alpha) }
            out.u8(straight(pixels[i + 2])); out.u8(straight(pixels[i + 1])); out.u8(straight(pixels[i])); out.u8(alpha)
        }
    }
    // Maschera: 1 dove il pixel è trasparente.
    for y in (0..<height).reversed() {
        var row = [UInt8](repeating: 0, count: maskRowBytes)
        for x in 0..<width where pixels[y * rowBytes + x * 4 + 3] == 0 {
            row[x / 8] |= 0x80 >> UInt8(x % 8)
        }
        out.data.append(contentsOf: row)
    }
    return out.data
}

/// File .ico con più dimensioni: DIB fino a 64 px, PNG da 256 px.
func ico(sizes: [Int], draw: (CGContext, CGFloat) -> Void) -> Data {
    let images = sizes.map { size -> (Int, Data) in
        let rep = bitmap(size: size, draw: draw)
        return (size, size >= 256 ? rep.representation(using: .png, properties: [:])! : dib(rep))
    }
    var out = LittleEndianWriter()
    out.u16(0); out.u16(1); out.u16(images.count)
    var offset = 6 + 16 * images.count
    for (size, image) in images {
        out.u8(size >= 256 ? 0 : size); out.u8(size >= 256 ? 0 : size); out.u8(0); out.u8(0)
        out.u16(1); out.u16(32); out.u32(image.count); out.u32(offset)
        offset += image.count
    }
    for (_, image) in images {
        out.data.append(image)
    }
    return out.data
}

// macOS: iconset con tutte le dimensioni richieste, poi iconutil.
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
iconutil.arguments = ["-c", "icns", iconset.path, "-o", icnsOutput.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { fatalError("iconutil non riuscito") }
print("Icona creata: \(icnsOutput.path)")

// Windows: icona dell'app e icone dell'area di notifica (100%–400% di ridimensionamento).
try FileManager.default.createDirectory(at: windowsResources, withIntermediateDirectories: true)
try ico(sizes: [16, 20, 24, 32, 40, 48, 64, 256]) { drawIcon(in: $0, size: $1, style: .windows) }
    .write(to: windowsResources.appendingPathComponent("AppIcon.ico"))
for (name, variant) in [("TrayCovering", TrayVariant.covering), ("TrayPaused", .paused), ("TrayOff", .off)] {
    try ico(sizes: [16, 20, 24, 32, 40, 48, 64]) { drawTrayIcon(in: $0, size: $1, variant: variant) }
        .write(to: windowsResources.appendingPathComponent("\(name).ico"))
}
print("Icone per Windows create in: \(windowsResources.path)")
