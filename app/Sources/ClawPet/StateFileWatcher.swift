import Foundation
import ClawPetCore

/// Polls ~/.claude/pet/state.json ~5x/sec and delivers the parsed StateName on the main
/// thread whenever it changes.
///
/// Why polling, not FSEvents: pet-state writes atomically (mktemp + `mv -f`), which REPLACES
/// the file's inode. An FSEvents watch bound to the old inode goes deaf after the first
/// replace (the path still exists as a new inode, so a "gone?" check never re-arms). For a
/// tiny state file, polling is both simpler and reliable. `mtime` gating keeps it cheap.
final class StateFileWatcher {
    private let path: String
    private let onState: (StateName) -> Void
    private var timer: Timer?
    private var lastMTime: TimeInterval = -1
    private var lastState: StateName?

    init(path: String, onState: @escaping (StateName) -> Void) {
        self.path = path
        self.onState = onState
        let t = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        poll()   // deliver initial state immediately
    }

    private func poll() {
        // Cheap gate: only re-read when the file's mtime changed.
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let m = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 {
            if m == lastMTime { return }
            lastMTime = m
        }
        let data = (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()
        let s = StateFileParser.parse(data)
        if s != lastState {
            lastState = s
            onState(s)
        }
    }
}
