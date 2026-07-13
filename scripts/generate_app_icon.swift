import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "Packaging/AppIcon-1024.png"
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else { exit(1) }

let rect = NSRect(origin: .zero, size: size)
let background = NSBezierPath(roundedRect: rect.insetBy(dx: 24, dy: 24), xRadius: 220, yRadius: 220)
NSColor(calibratedWhite: 0.035, alpha: 1).setFill()
background.fill()

let glow = NSBezierPath(ovalIn: NSRect(x: 180, y: 160, width: 664, height: 664))
NSColor(calibratedRed: 0.18, green: 0.86, blue: 0.52, alpha: 0.13).setFill()
glow.fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "SukhumvitSet-SemiBold", size: 390) ?? NSFont.systemFont(ofSize: 390, weight: .semibold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph,
    .kern: -14
]
NSAttributedString(string: "AI", attributes: attributes)
    .draw(in: NSRect(x: 120, y: 270, width: 784, height: 500))

let sparkleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 105, weight: .medium),
    .foregroundColor: NSColor(calibratedRed: 0.25, green: 0.95, blue: 0.62, alpha: 1)
]
NSAttributedString(string: "✦", attributes: sparkleAttributes)
    .draw(at: NSPoint(x: 756, y: 710))

context.flush()
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: output))
