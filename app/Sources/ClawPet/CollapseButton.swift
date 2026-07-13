import AppKit

/// A small pixel-styled "collapse" button pinned to the pet's top-right corner. It lives as a
/// top-most subview of PetView, so AppKit hit-tests it first and its clicks never reach the
/// pet's drag / hearts handlers. Hidden until the pointer hovers the pet (PetView toggles it).
final class CollapseButton: NSView {
    private let accent: NSColor
    var onCollapse: (() -> Void)?

    init(accent: NSColor) {
        self.accent = accent
        super.init(frame: NSRect(x: 0, y: 0, width: 22, height: 22))
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirty: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.interpolationQuality = .none
        let body = bounds.insetBy(dx: 2, dy: 2)
        // pixel rounded square: dark border, accent fill, light top highlight
        let border = NSBezierPath(roundedRect: body, xRadius: 4, yRadius: 4)
        accent.darkened(by: 0.35).setFill(); border.fill()
        let inner = body.insetBy(dx: 1.5, dy: 1.5)
        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(roundedRect: inner, xRadius: 3, yRadius: 3).setClip()
        accent.setFill(); NSBezierPath(rect: inner).fill()
        accent.lightened(by: 0.35).setFill()
        NSBezierPath(rect: NSRect(x: inner.minX, y: inner.maxY - 4, width: inner.width, height: 4)).fill()
        NSGraphicsContext.current?.restoreGraphicsState()
        // "collapse" glyph: a thick minus bar, dark, centered
        accent.darkened(by: 0.5).setFill()
        let bar = NSRect(x: body.minX + 5, y: body.midY - 1.5, width: body.width - 10, height: 3)
        NSBezierPath(rect: bar).fill()
    }

    override func mouseDown(with e: NSEvent) { /* swallow so PetView doesn't drag */ }
    override func mouseUp(with e: NSEvent) { onCollapse?() }
}
