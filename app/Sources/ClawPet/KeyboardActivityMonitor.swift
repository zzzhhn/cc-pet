import AppKit
import CoreGraphics

/// Listen-only global keyDown tap. Records ONLY that a key went down and when —
/// never the keycode or content.
///
/// On macOS 10.15+, a keyboard-listening CGEventTap needs the **Input Monitoring**
/// permission (System Settings > Privacy & Security > Input Monitoring), NOT
/// Accessibility. Checked with CGPreflightListenEventAccess(); prompted with
/// CGRequestListenEventAccess(). The permission is evaluated at process start, so after
/// granting it the app must be relaunched.
final class KeyboardActivityMonitor {
    private var tap: CFMachPort?
    private var lastKeyDown = Date.distantPast
    private let onActivity: () -> Void

    init(onPermission: @escaping (Bool) -> Void, onActivity: @escaping () -> Void) {
        self.onActivity = onActivity
        guard CGPreflightListenEventAccess() else {
            CGRequestListenEventAccess()   // shows the Input Monitoring prompt + lists the app
            onPermission(false)            // not granted this launch — grant, then relaunch
            return
        }
        onPermission(installTap())
    }

    private func installTap() -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let cb: CGEventTapCallBack = { _, _, _, refcon in
            let me = Unmanaged<KeyboardActivityMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            me.lastKeyDown = Date()
            DispatchQueue.main.async { me.onActivity() }
            return nil
        }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: mask, callback: cb, userInfo: refcon) else {
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        tap = t
        return true
    }

    var typingActive: Bool { Date().timeIntervalSince(lastKeyDown) < 1.5 }
}
