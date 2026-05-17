import AppKit
import Foundation

let fm = FileManager.default

guard CommandLine.arguments.count >= 8 else {
    fputs("Usage: swift render_caption_cards.swift <caption-dir> <width> <height> <font-name> <font-size> <text-width> <top-margin>\n", stderr)
    exit(1)
}

let dirURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let width = CGFloat(Double(CommandLine.arguments[2]) ?? 1920)
let height = CGFloat(Double(CommandLine.arguments[3]) ?? 1080)
let fontName = CommandLine.arguments[4]
let fontSize = CGFloat(Double(CommandLine.arguments[5]) ?? 40)
let textWidth = CGFloat(Double(CommandLine.arguments[6]) ?? 1560)
let topMargin = CGFloat(Double(CommandLine.arguments[7]) ?? 64)

let size = NSSize(width: width, height: height)
let font = NSFont(name: fontName, size: fontSize)
    ?? NSFont(name: "HelveticaNeue-Light", size: fontSize)
    ?? NSFont.systemFont(ofSize: fontSize, weight: .light)

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
paragraph.lineBreakMode = .byWordWrapping

let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.96),
    .paragraphStyle: paragraph,
    .kern: 0.6
]

let textFiles = try fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "txt" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

for textFile in textFiles {
    let text = try String(contentsOf: textFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    let attributed = NSAttributedString(string: text, attributes: attrs)
    let bounds = attributed.boundingRect(
        with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading]
    ).integral

    let canvas = NSImage(size: size)
    canvas.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        fputs("Could not create graphics context\n", stderr)
        exit(1)
    }

    ctx.clear(CGRect(origin: .zero, size: size))

    let textRect = CGRect(
        x: (width - textWidth) / 2,
        y: height - topMargin - bounds.height - 8,
        width: textWidth,
        height: bounds.height + 12
    )

    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.55)
    shadow.shadowBlurRadius = 5
    shadow.shadowOffset = .init(width: 0, height: -1)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    attributed.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    NSGraphicsContext.restoreGraphicsState()

    canvas.unlockFocus()

    guard
        let tiff = canvas.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        fputs("Could not encode PNG for \(textFile.lastPathComponent)\n", stderr)
        exit(1)
    }

    let outURL = dirURL.appendingPathComponent(textFile.deletingPathExtension().lastPathComponent + ".png")
    try png.write(to: outURL)
}
