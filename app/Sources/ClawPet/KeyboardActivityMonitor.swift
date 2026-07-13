import AppKit
import ApplicationServices

/// Listen-only global keyDown tap. Records ONLY that a key went down and when —
/// never the keycode or content. Requires Accessibility permission.
///
/// A CGEventTap can only be created AFTER Accessibility permission is granted. Because
/// macOS re-signs the app on every build (invalidating a prior grant), and because the
/// user often grants permission *after* launch, this prompts on launch and then RETRIES
/// tap creation until it succeeds — so granting permission takes effect without a relaunch.
final class KeyboardActivityMonitor {
    private var tap: CFMachPort?
    private var lastKeyDown = Date.distantPast
    private let onActivity: () -> Void
    private let onPermission: (Bool) -> Void
    private var retryTimer: Timer?

    init(onPermission: @escaping (Bool) -> Void, onActivity: @escaping () -> Void) {
        self.onActivity = onActivity
        self.onPermission = onPermission

        // Show the system Accessibility grant dialog and list this app if not yet trusted.
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)

        if !tryInstallTap() {
            onPermission(false)
            // Poll for the grant; install the tap the moment we become trusted.
            let t = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                if AXIsProcessTrusted(), self.tryInstallTap() {
                    self.onPermission(true)
                    self.retryTimer?.invalidate(); self.retryTimer = nil
                }
            }
            RunLoop.main.add(t, forMode: .common)
            retryTimer = t
        } else {
            onPermission(true)
        }
    }

    /// Create the event tap. Returns true on success (requires Accessibility permission).
    private func tryInstallTap() -> Bool {
        if tap != nil { return true }
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
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        tap = t
        return true
    }

    var typingActive: Bool { Date().timeIntervalSince(lastKeyDown) < 1.5 }
}
