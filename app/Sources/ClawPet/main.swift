import AppKit
import ClawPetCore

/// Holds @objc menu actions (top-level code cannot define @objc selectors).
final class AppCoordinator: NSObject {
    @objc func openAccessibility() {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc func quit() { NSApplication.shared.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // menubar only, no Dock icon
let coordinator = AppCoordinator()

let petDir = ("~/.claude/pet/pets/placeholder" as NSString).expandingTildeInPath
let controller = PetController(petDir: petDir)

let window = PetWindow(size: NSSize(width: 192, height: 208))
window.contentView = controller.contentView
(controller.contentView as? PetView)?.controller = controller
if let saved = Persistence.loadOrigin() {
    window.setFrameOrigin(saved)
} else if let f = NSScreen.main?.visibleFrame {
    window.setFrameOrigin(NSPoint(x: f.maxX - 220, y: f.minY + 40))
}
window.orderFrontRegardless()

let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
status.button?.title = "🧚"
let menu = NSMenu()
let quitItem = NSMenuItem(title: "Quit ClawPet", action: #selector(AppCoordinator.quit), keyEquivalent: "q")
quitItem.target = coordinator
menu.addItem(quitItem)
status.menu = menu

// M2: Claude Code state file -> external state
let stateFile = ("~/.claude/pet/state.json" as NSString).expandingTildeInPath
let watcher = StateFileWatcher(path: stateFile) { state in
    controller.machine.setExternal(state)
    controller.apply()
}
_ = watcher

// M2: keyboard activity -> typing state
let kbd = KeyboardActivityMonitor(onPermission: { granted in
    status.button?.title = granted ? "🧚" : "🧚⚠️"
    if !granted {
        let item = NSMenuItem(title: "键盘感知:未授权 (打开系统设置)",
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
