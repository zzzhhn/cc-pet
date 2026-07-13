import AppKit

enum Persistence {
    private static let key = "clawpet.window.origin"
    static func saveOrigin(_ p: NSPoint) {
        UserDefaults.standard.set(["x": Double(p.x), "y": Double(p.y)], forKey: key)
    }
    static func loadOrigin() -> NSPoint? {
        guard let d = UserDefaults.standard.dictionary(forKey: key),
              let x = d["x"] as? Double, let y = d["y"] as? Double else { return nil }
        return NSPoint(x: x, y: y)
    }
}
