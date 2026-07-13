import AppKit

extension NSWindow {
    /// Nudge the window so at least `margin` points of it stay within some screen's visible
    /// frame on each axis. Borderless floating windows are otherwise unconstrained and can be
    /// dragged fully off-screen, becoming unreachable (you can't click or grab what you can't
    /// see). Call on drag-end and whenever a saved/off-screen origin is restored.
    func clampOntoScreen(margin: CGFloat = 24) {
        let f = frame
        // Prefer the screen the window already overlaps; else the one nearest its center; else main.
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(f) })
            ?? NSScreen.screens.min(by: {
                abs($0.frame.midX - f.midX) + abs($0.frame.midY - f.midY)
                    < abs($1.frame.midX - f.midX) + abs($1.frame.midY - f.midY)
            })
            ?? NSScreen.main
        guard let vf = screen?.visibleFrame else { return }
        var o = f.origin
        o.x = min(max(o.x, vf.minX - f.width + margin), vf.maxX - margin)
        o.y = min(max(o.y, vf.minY - f.height + margin), vf.maxY - margin)
        if o != f.origin { setFrameOrigin(o) }
    }
}
