import AppKit

enum Persistence {
    private static let key = "clawpet.window.origin"
    private static let bubbleKey = "clawpet.bubble.origin"
    private static let collapsedKey = "clawpet.collapsed"

    static func saveOrigin(_ p: NSPoint) { savePoint(p, key) }
    static func loadOrigin() -> NSPoint? { loadPoint(key) }

    static func saveBubbleOrigin(_ p: NSPoint) { savePoint(p, bubbleKey) }
    static func loadBubbleOrigin() -> NSPoint? { loadPoint(bubbleKey) }

    static func saveCollapsed(_ v: Bool) { UserDefaults.standard.set(v, forKey: collapsedKey) }
    static func loadCollapsed() -> Bool { UserDefaults.standard.bool(forKey: collapsedKey) }

    private static func savePoint(_ p: NSPoint, _ k: String) {
        UserDefaults.standard.set(["x": Double(p.x), "y": Double(p.y)], forKey: k)
    }
    private static func loadPoint(_ k: String) -> NSPoint? {
        guard let d = UserDefaults.standard.dictionary(forKey: k),
              let x = d["x"] as? Double, let y = d["y"] as? Double else { return nil }
        return NSPoint(x: x, y: y)
    }
}
