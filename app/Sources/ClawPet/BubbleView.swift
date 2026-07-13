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

        // --- red waiting badge, top-right (pixel-quantized on the same 2pt grid as the bubble) ---
        guard waiting > 0 else { return }
        let bcx = bounds.maxX - 13, bcy = bounds.maxY - 13   // inset so the full white rim shows
        fillPixelDisc(cx: bcx, cy: bcy, r: 11, unit: unit, color: .white)       // white rim
        fillPixelDisc(cx: bcx, cy: bcy, r: 9, unit: unit, color: .systemRed)    // red body
        drawPixelText(waiting > 9 ? "9+" : "\(waiting)", cx: bcx, cy: bcy, px: unit, color: .white)
    }

    /// Fill a disc as square cells snapped to the view's global unit grid, so the badge's pixels
    /// line up with the bubble's (no antialiasing — hard pixel edges).
    private func fillPixelDisc(cx: CGFloat, cy: CGFloat, r: CGFloat, unit: CGFloat, color: NSColor) {
        color.setFill()
        let x0 = bounds.minX + floor((cx - r - bounds.minX) / unit) * unit
        let y0 = bounds.minY + floor((cy - r - bounds.minY) / unit) * unit
        var y = y0
        while y <= cy + r {
            var x = x0
            while x <= cx + r {
                if hypot(x + unit / 2 - cx, y + unit / 2 - cy) <= r {
                    NSBezierPath(rect: CGRect(x: x, y: y, width: unit, height: unit)).fill()
                }
                x += unit
            }
            y += unit
        }
    }

    /// Tiny 3x5 pixel font for the badge count (digits + "+"), drawn cell by cell, grid-snapped.
    private static let pixelFont: [Character: [UInt8]] = [
        "0": [0b111, 0b101, 0b101, 0b101, 0b111],
        "1": [0b010, 0b110, 0b010, 0b010, 0b111],
        "2": [0b111, 0b001, 0b111, 0b100, 0b111],
        "3": [0b111, 0b001, 0b111, 0b001, 0b111],
        "4": [0b101, 0b101, 0b111, 0b001, 0b001],
        "5": [0b111, 0b100, 0b111, 0b001, 0b111],
        "6": [0b111, 0b100, 0b111, 0b101, 0b111],
        "7": [0b111, 0b001, 0b001, 0b010, 0b010],
        "8": [0b111, 0b101, 0b111, 0b101, 0b111],
        "9": [0b111, 0b101, 0b111, 0b001, 0b111],
        "+": [0b000, 0b010, 0b111, 0b010, 0b000],
    ]

    private func drawPixelText(_ s: String, cx: CGFloat, cy: CGFloat, px: CGFloat, color: NSColor) {
        color.setFill()
        let glyphs = s.compactMap { Self.pixelFont[$0] }
        guard !glyphs.isEmpty else { return }
        let cols = 3, rows = 5, gap = 1
        let totalCols = glyphs.count * cols + (glyphs.count - 1) * gap
        // snap the text block to the same unit grid used everywhere else
        let startX = bounds.minX + (floor((cx - CGFloat(totalCols) * px / 2 - bounds.minX) / px)) * px
        let topY = bounds.minY + (floor((cy + CGFloat(rows) * px / 2 - bounds.minY) / px)) * px
        var penX = startX
        for g in glyphs {
            for (r, bits) in g.enumerated() {
                for c in 0..<cols where (bits >> (cols - 1 - c)) & 1 == 1 {
                    let x = penX + CGFloat(c) * px
                    let y = topY - CGFloat(r + 1) * px
                    NSBezierPath(rect: CGRect(x: x, y: y, width: px, height: px)).fill()
                }
            }
            penX += CGFloat(cols + gap) * px
        }
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
