import AppKit
import ClawPetCore

/// Holds @objc menu actions (top-level code cannot define @objc selectors).
final class AppCoordinator: NSObject {
    var onToggleCollapse: (() -> Void)?
    @objc func openAccessibility() {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc func toggleCollapse() { onToggleCollapse?() }
    @objc func quit() { NSApplication.shared.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // menubar only, no Dock icon
let coordinator = AppCoordinator()

let petDir = ("~/.claude/pet/pets/fairy-singer" as NSString).expandingTildeInPath
let controller = PetController(petDir: petDir)

let window = PetWindow(size: NSSize(width: 192, height: 208))
window.contentView = controller.contentView
(controller.contentView as? PetView)?.controller = controller
if let saved = Persistence.loadOrigin() {
    window.setFrameOrigin(saved)
} else if let f = NSScreen.main?.visibleFrame {
    window.setFrameOrigin(NSPoint(x: f.maxX - 220, y: f.minY + 40))
}

// --- Collapsed bubble ---------------------------------------------------------------
// Accent from the manifest (fairy teal), or a default teal for atlas-less placeholders.
let accent = controller.manifest.accentColor.flatMap { NSColor.fromHex($0) }
    ?? NSColor(red: 0.50, green: 0.79, blue: 0.77, alpha: 1)
// Idle (hover) cell in atlas pixel coords (top-left origin, as CGImage.cropping expects).
let atlas = controller.atlasImage
let rows = controller.manifest.states.count
let cellW = CGFloat(atlas.width) / 8
let cellH = CGFloat(atlas.height) / CGFloat(rows)
let hoverRow = controller.manifest.state(.hover)?.row ?? 1
let idleCell = CGRect(x: 0, y: CGFloat(hoverRow) * cellH, width: cellW, height: cellH)

let bubbleWindow = BubbleWindow(size: NSSize(width: 56, height: 56))
let bubbleView = BubbleView(atlas: atlas, cellRect: idleCell, accent: accent)
bubbleWindow.contentView = bubbleView
if let bo = Persistence.loadBubbleOrigin() {
    bubbleWindow.setFrameOrigin(bo)
} else if let f = NSScreen.main?.visibleFrame {
    bubbleWindow.setFrameOrigin(NSPoint(x: f.maxX - 80, y: f.minY + 40))
}
bubbleView.onMoved = { Persistence.saveBubbleOrigin($0) }

let collapse = {
    window.orderOut(nil)
    bubbleWindow.orderFrontRegardless()
    Persistence.saveCollapsed(true)
}
let expand = {
    bubbleWindow.orderOut(nil)
    window.orderFrontRegardless()
    Persistence.saveCollapsed(false)
}
(controller.contentView as? PetView)?.installCollapse(accent: accent, onCollapse: collapse)
bubbleView.onExpand = expand

// Restore last collapsed/expanded state.
if Persistence.loadCollapsed() { bubbleWindow.orderFrontRegardless() }
else { window.orderFrontRegardless() }

let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
status.button?.title = "🧚"
let menu = NSMenu()
coordinator.onToggleCollapse = { Persistence.loadCollapsed() ? expand() : collapse() }
let toggleItem = NSMenuItem(title: "Collapse / Expand", action: #selector(AppCoordinator.toggleCollapse), keyEquivalent: "")
toggleItem.target = coordinator
menu.addItem(toggleItem)
menu.addItem(.separator())
let quitItem = NSMenuItem(title: "Quit ClawPet", action: #selector(AppCoordinator.quit), keyEquivalent: "q")
quitItem.target = coordinator
menu.addItem(quitItem)
status.menu = menu

// M2 + bubble: per-session state files -> pet display + waiting-window badge count.
let stateFile = ("~/.claude/pet/state.json" as NSString).expandingTildeInPath
let sessionsDir = ("~/.claude/pet/sessions" as NSString).expandingTildeInPath
let watcher = StateFileWatcher(sessionsDir: sessionsDir, fallbackFile: stateFile) { display, waiting in
    controller.machine.setExternal(display)
    controller.apply()
    bubbleView.setWaiting(waiting)
}
_ = watcher

// M2: keyboard activity -> typing state
let kbd = KeyboardActivityMonitor(onPermission: { granted in
    status.button?.title = granted ? "🧚" : "🧚⚠️"
    if !granted {
        let item = NSMenuItem(title: "键盘感知:未授权 (输入监控)",
            action: #selector(AppCoordinator.openAccessibility), keyEquivalent: "")
        item.target = coordinator
        menu.insertItem(item, at: 0)
    }
}, onActivity: {})
let typingTimer = Timer(timeInterval: 0.25, repeats: true) { _ in
    let before = controller.machine.display
    controller.machine.setTyping(kbd.typingActive)
    if controller.machine.display != before { controller.apply() }
}
RunLoop.main.add(typingTimer, forMode: .common)

// Random friendly wave: every 30s, 50% chance, only when the pet is just resting
// (not dragging/typing/mid-gesture). Replaces the old hover-to-wave trigger.
let waveTimer = Timer(timeInterval: 30, repeats: true) { _ in
    if controller.machine.isHoverIdle && Bool.random() {
        controller.machine.triggerInteraction(.wave)
        controller.apply()
    }
}
RunLoop.main.add(waveTimer, forMode: .common)

app.run()
