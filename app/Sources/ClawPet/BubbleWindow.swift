import AppKit

/// Transparent floating window that hosts the collapsed BubbleView. Same window traits as
/// PetWindow (borderless, floating level, joins all Spaces) so the bubble behaves like the pet.
final class BubbleWindow: NSWindow {
    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
    }
    override var canBecomeKey: Bool { true }
}
