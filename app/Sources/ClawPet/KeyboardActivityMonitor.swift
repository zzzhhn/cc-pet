import AppKit

/// Listen-only global keyDown tap. Records ONLY that a key went down and when.
/// Never reads keycode or content. Requires Accessibility permission; if the tap
/// cannot be created, reports permission=false and typing detection is disabled.
final class KeyboardActivityMonitor {
    private var tap: CFMachPort?
    private var lastKeyDown = Date.distantPast
    private let onActivity: () -> Void

    init(onPermission: (Bool) -> Void, onActivity: @escaping () -> Void) {
        self.onActivity = onActivity
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let cb: CGEventTapCallBack = { _, _, _, refcon in
            let me = Unmanaged<KeyboardActivityMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            me.lastKeyDown = Date()
            DispatchQueue.main.async { me.onActivity() }
            return nil
        }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: mask, callback: cb, userInfo: refcon)
        if let tap {
            let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            onPermission(true)
        } else {
            onPermission(false)
        }
    }
    var typingActive: Bool { Date().timeIntervalSince(lastKeyDown) < 1.5 }
}
