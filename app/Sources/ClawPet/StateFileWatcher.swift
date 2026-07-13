import Foundation
import ClawPetCore

/// Polls ~/.claude/pet/sessions/*.state.json ~5x/sec and delivers (displayState, waitingCount)
/// on the main thread whenever either changes.
///
/// - displayState = the most recently active session's state (multi-window: newest wins).
/// - waitingCount = how many sessions are currently waiting on the user (bubble badge),
///   with a TTL so a window closed/crashed while waiting stops counting.
///
/// Why polling, not FSEvents: pet-state writes each file atomically (mktemp + `mv -f`), which
/// REPLACES the inode. An FSEvents watch bound to the old inode goes deaf after the first
/// replace. For tiny state files, polling a directory is simpler and reliable. An mtime/count
/// signature gates the re-read; the waiting count is still recomputed every tick because a
/// session can go stale purely by time passing (no file change).
///
/// Fallback: if the sessions directory is empty/absent (legacy or first launch), it reads the
/// single `state.json` so single-window setups still animate.
final class StateFileWatcher {
    private let sessionsDir: String
    private let fallbackFile: String
    private let ttlSec: Int
    private let onUpdate: (StateName, Int) -> Void

    private var timer: Timer?
    private var lastSignature: String = ""
    private var cached: [SessionState] = []
    private var lastDelivered: (StateName, Int)?

    init(sessionsDir: String, fallbackFile: String, ttlSec: Int = 900,
         onUpdate: @escaping (StateName, Int) -> Void) {
        self.sessionsDir = sessionsDir
        self.fallbackFile = fallbackFile
        self.ttlSec = ttlSec
        self.onUpdate = onUpdate
        let t = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        poll()   // deliver initial state immediately
    }

    private func poll() {
        let files = sessionFiles()
        let signature = files.map { "\($0.path):\($0.mtime)" }.joined(separator: "|")
        if signature != lastSignature {
            lastSignature = signature
            cached = files.isEmpty ? fallbackSessions() : files.compactMap { parse($0.path) }
        }
        let now = Int(Date().timeIntervalSince1970)
        let display = SessionStates.latestState(cached) ?? .hover
        let waiting = SessionStates.waitingCount(cached, now: now, ttlSec: ttlSec)
        if lastDelivered?.0 != display || lastDelivered?.1 != waiting {
            lastDelivered = (display, waiting)
            onUpdate(display, waiting)
        }
    }

    private func sessionFiles() -> [(path: String, mtime: TimeInterval)] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: sessionsDir) else { return [] }
        return names.filter { $0.hasSuffix(".state.json") }.map { name in
            let path = (sessionsDir as NSString).appendingPathComponent(name)
            let m = ((try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date)?
                .timeIntervalSince1970 ?? 0
            return (path, m)
        }
    }

    private func parse(_ path: String) -> SessionState? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return StateFileParser.parseSession(data)
    }

    /// Legacy single-file path: stamp it with `now` so it's always "fresh" (a lone window's
    /// waiting still lights the badge) and never goes stale on its own.
    private func fallbackSessions() -> [SessionState] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: fallbackFile)) else { return [] }
        return [SessionState(state: StateFileParser.parse(data), ts: Int(Date().timeIntervalSince1970))]
    }
}
