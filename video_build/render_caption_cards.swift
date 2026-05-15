import AppKit
import Foundation

let fm = FileManager.default

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: swift render_caption_cards.swift <caption-dir>\n", stderr)
    exit(1)
}

let dirURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let size = NSSize(width: 1080, height: 1920)
let textWidth: CGFloat = 820
let boxPaddingX: CGFloat = 34
let boxPaddingY: CGFloat = 26
let bottomMargin: CGFloat = 180
let font = NSFont(name: "Arial Bold", size: 58) ?? NSFont.boldSystemFont(ofSize: 58)

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
paragraph.lineBreakMode = .byWordWrapping

let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph
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

    let boxWidth = min(size.width - 120, bounds.width + boxPaddingX * 2)
    let boxHeight = bounds.height + boxPaddingY * 2
    let boxRect = CGRect(
        x: (size.width - boxWidth) / 2,
        y: bottomMargin,
        width: boxWidth,
        height: boxHeight
    )

    let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: 28, yRadius: 28)
    NSColor(calibratedWhite: 0.0, alpha: 0.34).setFill()
    boxPath.fill()

    let textRect = CGRect(
        x: (size.width - textWidth) / 2,
        y: boxRect.minY + boxPaddingY - 2,
        width: textWidth,
        height: bounds.height + 10
    )

    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.45)
    shadow.shadowBlurRadius = 4
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
    print(outURL.path)
}
