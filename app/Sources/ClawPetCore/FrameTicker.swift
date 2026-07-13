public struct FrameTicker: Sendable {
    public let durations: [Int]
    public let loop: Bool
    public init(durations: [Int], loop: Bool) { self.durations = durations; self.loop = loop }

    public func frame(atElapsedMs t: Int) -> (index: Int, finished: Bool) {
        let total = durations.reduce(0, +)
        if total <= 0 || durations.isEmpty { return (0, true) }
        var e = t
        if loop { e = ((t % total) + total) % total }
        else if t >= total { return (durations.count - 1, true) }
        var acc = 0
        for (i, d) in durations.enumerated() { acc += d; if e < acc { return (i, false) } }
        return (durations.count - 1, !loop)
    }
}
