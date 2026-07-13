import AppKit
import ClawPetCore

final class PetView: NSView {
    private let geo: AtlasGeometry
    weak var controller: PetController?
    private var dragStart: NSPoint = .zero
    private var winStart: NSPoint = .zero
    private var didDrag = false
    private var lastDragDir: DragDirection?
    private var lastMouse: NSPoint = .zero

    private var collapseButton: CollapseButton?

    init(image: CGImage, geometry: AtlasGeometry) {
        self.geo = geometry
        super.init(frame: .zero)
        wantsLayer = true
        layer?.contents = image
        layer?.magnificationFilter = .nearest
        layer?.contentsGravity = .resizeAspect
    }
    required init?(coder: NSCoder) { fatalError() }

    /// Add the top-right "collapse into bubble" button. Hidden until the pointer hovers the pet.
    func installCollapse(accent: NSColor, onCollapse: @escaping () -> Void) {
        let b = CollapseButton(accent: accent)
        b.onCollapse = onCollapse
        b.isHidden = true
        b.autoresizingMask = [.minXMargin, .minYMargin]   // pin to top-right
        b.setFrameOrigin(NSPoint(x: bounds.maxX - b.frame.width - 4, y: bounds.maxY - b.frame.height - 4))
        addSubview(b)
        collapseButton = b
    }

    /// Show cell (row, frame). AtlasGeometry uses top-left origin; CALayer contentsRect
    /// origin is bottom-left, so flip Y: yLayer = 1 - (row+1)*h.
    func show(row: Int, frame: Int) {
        let r = geo.rect(row: row, frame: frame)
        layer?.contentsRect = CGRect(x: r.minX, y: 1 - r.minY - r.height, width: r.width, height: r.height)
    }

    override func viewDidMoveToWindow() {
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    // Reveal the collapse button only while hovering the pet (keeps the pet uncluttered at rest).
    override func mouseEntered(with e: NSEvent) { collapseButton?.isHidden = false }
    override func mouseExited(with e: NSEvent) { collapseButton?.isHidden = true }

    override func mouseDown(with e: NSEvent) {
        dragStart = NSEvent.mouseLocation
        winStart = window?.frame.origin ?? .zero
        didDrag = false
        lastDragDir = nil
        lastMouse = NSEvent.mouseLocation
    }
    override func mouseDragged(with e: NSEvent) {
        didDrag = true
        let now = NSEvent.mouseLocation
        let dx = now.x - dragStart.x, dy = now.y - dragStart.y
        window?.setFrameOrigin(NSPoint(x: winStart.x + dx, y: winStart.y + dy))
        // Direction from INSTANTANEOUS motion (vs last event), not cumulative from the
        // grab point — otherwise reversing requires dragging back past the origin (laggy).
        // apply() only on an actual direction change, so the fly loop is not reset every event.
        let vx = now.x - lastMouse.x
        lastMouse = now
        if abs(vx) > 0.5 {
            let dir: DragDirection = vx < 0 ? .left : .right
            if dir != lastDragDir {
                lastDragDir = dir
                controller?.machine.setDragging(dir)
                controller?.apply()
            }
        }
    }
    override func mouseUp(with e: NSEvent) {
        controller?.machine.setDragging(nil)
        controller?.apply()
        if didDrag {
            Persistence.saveOrigin(window?.frame.origin ?? .zero)
        } else if e.clickCount == 2 {
            fire(.twirl)
        } else if e.clickCount == 1 {
            fire(.hearts)
        }
    }
    override func rightMouseDown(with e: NSEvent) {
        let m = NSMenu()
        let hide = NSMenuItem(title: "Hide", action: #selector(hidePet), keyEquivalent: "")
        hide.target = self
        m.addItem(hide)
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        m.addItem(quit)
        NSMenu.popUpContextMenu(m, with: e, for: self)
    }
    @objc private func hidePet() { window?.orderOut(nil) }

    private func fire(_ s: StateName) {
        controller?.machine.triggerInteraction(s)
        controller?.apply()
    }
}
