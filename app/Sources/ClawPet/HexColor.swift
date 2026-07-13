import AppKit

extension NSColor {
    /// Parse "#RRGGBB" (or "RRGGBB"). Returns nil on malformed input so callers fall back
    /// to a default rather than silently rendering black.
    static func fromHex(_ hex: String) -> NSColor? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        return NSColor(
            red: CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255,
            alpha: 1)
    }

    /// A darker shade for pixel borders/outlines.
    func darkened(by f: CGFloat) -> NSColor {
        guard let c = usingColorSpace(.deviceRGB) else { return self }
        return NSColor(red: c.redComponent * (1 - f), green: c.greenComponent * (1 - f),
                       blue: c.blueComponent * (1 - f), alpha: c.alphaComponent)
    }

    /// A lighter tint for pixel highlights.
    func lightened(by f: CGFloat) -> NSColor {
        guard let c = usingColorSpace(.deviceRGB) else { return self }
        return NSColor(red: c.redComponent + (1 - c.redComponent) * f,
                       green: c.greenComponent + (1 - c.greenComponent) * f,
                       blue: c.blueComponent + (1 - c.blueComponent) * f, alpha: c.alphaComponent)
    }
}
