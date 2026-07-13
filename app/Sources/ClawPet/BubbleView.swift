import AppKit

/// The collapsed pixel bubble: a chunky pixel-art soap bubble (a quantized circle with a rim and
/// a glint) in the pet's accent color, with a mini idle thumbnail floating inside and a red badge
/// counting waiting windows. Drawn as a grid of square cells so the circle reads as pixel art
/// (matching the sprite), not a smooth vector shape. Drag to move, click to expand.
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
        ctx.setShouldAntialias(false)

        let cx = bounds.midX, cy = bounds.midY
        let R: CGFloat = 25            // outer radius (leaves a 3pt margin in the 56pt view)
        let unit: CGFloat = 2          // art-pixel size -> chunky quantized circle
        let inner = R - 2              // body radius inside the rim

        // --- pixel circle: rim ring + accent body, cell by cell ---
        let rim = accent.darkened(by: 0.45)
        var y = bounds.minY
        while y < bounds.maxY {
            var x = bounds.minX
            while x < bounds.maxX {
                let d = hypot(x + unit / 2 - cx, y + unit / 2 - cy)
                if d <= R {
                    (d >= R - 2 ? rim : accent).setFill()
                    NSBezierPath(rect: CGRect(x: x, y: y, width: unit, height: unit)).fill()
                }
                x += unit
            }
            y += unit
        }

        // --- mini idle thumbnail, clipped to the inner circle, nearest-neighbor ---
        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(ovalIn: CGRect(x: cx - inner, y: cy - inner, width: 2 * inner, height: 2 * inner)).setClip()
        if let cell = atlas.cropping(to: cellRect) {
            let img = NSImage(cgImage: cell, size: NSSize(width: cellRect.width, height: cellRect.height))
            let w = inner * 2 * 0.80
            let h = w * (cellRect.height / cellRect.width)
            let rect = NSRect(x: cx - w / 2, y: cy - h / 2 + 1, width: w, height: h)
            img.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
                     respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
        }
        // --- glossy glint on the bubble surface (top-left), on top of the sprite ---
        accent.lightened(by: 0.78).setFill()
        NSBezierPath(rect: CGRect(x: cx - 15, y: cy + 9, width: 4, height: 4)).fill()
        NSBezierPath(rect: CGRect(x: cx - 11, y: cy + 13, width: 2, height: 2)).fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        // --- red waiting badge, top-right, above everything ---
        guard waiting > 0 else { return }
        ctx.setShouldAntialias(true)
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

    // Drag to move (clamped on release so it can't be lost off-screen), click to expand.
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
        if didDrag {
            window?.clampOntoScreen()
            onMoved?(window?.frame.origin ?? .zero)
        } else {
            onExpand?()
        }
    }
}
