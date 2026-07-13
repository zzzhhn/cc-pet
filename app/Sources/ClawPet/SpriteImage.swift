import AppKit
enum SpriteImage {
    static func load(_ path: String) -> CGImage? {
        guard let img = NSImage(contentsOfFile: path),
              let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return cg
    }
    /// Visible magenta placeholder so a missing atlas never renders blank (spec: no silent failure).
    static func magentaPlaceholder() -> CGImage {
        let s = 192
        let ctx = CGContext(data: nil, width: s, height: s, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(NSColor.magenta.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
        return ctx.makeImage()!
    }
}
