import AppKit

/// The collapsed pixel bubble: an accent-colored rounded pixel body with a mini idle-frame
/// thumbnail of the pet, plus a red badge counting how many Claude Code windows are waiting.
/// Everything is drawn in one Core Graphics pass (nearest-neighbor) so the pixel look and the
/// on-top badge stay consistent without CALayer z-ordering games. Drag to move, click to expand.
final class BubbleView: NSView {
    private let atlas: CGImage
    private let cellRect: CGRect     // idle cell in atlas pixel coords (top-left origin)
    private let accent: NSColor
    private var waiting = 0

    var onExpand: (() -> Void)?
    var onMoved: ((NSPoint) -> Void)?

    private var dragStart = NSPoint.zero
    private var winStart = NSPoint.zero
    private var didDrag = false

    init(atlas: CGImage, cellRect: CGRect, accent: NSColor) {
        self.atlas = atlas
        self.cellRect = cellRect
        self.accent = accent
        super.init(frame: NSRect(x: 0, y: 0, width: 56, height: 56))
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    func setWaiting(_ n: Int) {
        guard n != waiting else { return }
        waiting = n
        needsDisplay = true
    }

    override func draw(_ dirty: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.interpolationQuality = .none

        // --- pixel bubble body: dark border, accent fill, light top highlight ---
        let body = bounds.insetBy(dx: 3, dy: 3)
        accent.darkened(by: 0.4).setFill()
        NSBezierPath(roundedRect: body, xRadius: 12, yRadius: 12).fill()
        let inner = body.insetBy(dx: 2, dy: 2)
        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(roundedRect: inner, xRadius: 10, yRadius: 10).setClip()
        accent.setFill(); NSBezierPath(rect: inner).fill()
        accent.lightened(by: 0.4).setFill()
        NSBezierPath(rect: NSRect(x: inner.minX, y: inner.maxY - inner.height * 0.42,
                                  width: inner.width, height: inner.height * 0.42)).fill()

        // --- mini idle thumbnail, clipped to the bubble, nearest-neighbor ---
        if let cell = atlas.cropping(to: cellRect) {
            let img = NSImage(cgImage: cell, size: NSSize(width: cellRect.width, height: cellRect.height))
            // fit the cell into the inner circle with a little padding; bias up so feet don't clip
            let side = inner.width * 0.86
            let h = side * (cellRect.height / cellRect.width)
            let rect = NSRect(x: inner.midX - side / 2, y: inner.midY - h / 2 + 2, width: side, height: h)
            img.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
                     respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
        }
        NSGraphicsContext.current?.restoreGraphicsState()

        // --- red waiting badge, top-right, on top of everything ---
        guard waiting > 0 else { return }
        let d: CGFloat = 22
        let badge = NSRect(x: bounds.maxX - d, y: bounds.maxY - d, width: d, height: d)
        NSColor.white.setFill(); NSBezierPath(ovalIn: badge.insetBy(dx: -1, dy: -1)).fill()  // white ring
        NSColor.systemRed.setFill(); NSBezierPath(ovalIn: badge).fill()
        let label = waiting > 9 ? "9+" : "\(waiting)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: waiting > 9 ? 11 : 13, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let size = label.size(withAttributes: attrs)
        label.draw(at: NSPoint(x: badge.midX - size.width / 2, y: badge.midY - size.height / 2), withAttributes: attrs)
    }

    // Drag to move (persist), click (no drag) to expand.
    override func mouseDown(with e: NSEvent) {
        dragStart = NSEvent.mouseLocation
        winStart = window?.frame.origin ?? .zero
        didDrag = false
    }
    override func mouseDragged(with e: NSEvent) {
        didDrag = true
        let now = NSEvent.mouseLocation
        window?.setFrameOrigin(NSPoint(x: winStart.x + (now.x - dragStart.x),
                                       y: winStart.y + (now.y - dragStart.y)))
    }
    override func mouseUp(with e: NSEvent) {
        if didDrag { onMoved?(window?.frame.origin ?? .zero) } else { onExpand?() }
    }
}
