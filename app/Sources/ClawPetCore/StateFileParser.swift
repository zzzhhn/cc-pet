import Foundation

public struct PetStateFile: Codable, Sendable {
    public let state: String
    public let ts: Int?
    public let session: String?
}

public enum StateFileParser {
    public static func parse(_ data: Data) -> StateName {
        guard let f = try? JSONDecoder().decode(PetStateFile.self, from: data) else { return .hover }
        return StateName.parse(f.state)
    }

    /// Parse one per-session state file into a `SessionState`. Returns nil on corrupt JSON
    /// so the caller can skip a half-written file (the hook writes atomically, but a poll
    /// can still race a delete). Missing `ts` defaults to 0 → treated as maximally stale.
    public static func parseSession(_ data: Data) -> SessionState? {
        guard let f = try? JSONDecoder().decode(PetStateFile.self, from: data) else { return nil }
        return SessionState(state: StateName.parse(f.state), ts: f.ts ?? 0)
    }
}
