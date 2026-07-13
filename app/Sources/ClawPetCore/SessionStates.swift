/// Per-session state aggregation. Every Claude Code window writes its own
/// `sessions/<session_id>.state.json`; the app reads them all and reduces to two things:
/// which state the pet should show (the most recently active session) and how many
/// windows are currently waiting on the user (the bubble badge count).
///
/// Recency is keyed off the embedded `ts` (epoch seconds the hook stamps on every write),
/// not filesystem mtime — so this stays a pure, testable reduction with no I/O.
public struct SessionState: Equatable, Sendable {
    public let state: StateName
    public let ts: Int   // epoch seconds when the hook last wrote this session
    public init(state: StateName, ts: Int) {
        self.state = state
        self.ts = ts
    }
}

public enum SessionStates {
    /// The pet's display state = the state of the most recently updated session
    /// (highest `ts`). Ties broken arbitrarily. `nil` when there are no sessions.
    public static func latestState(_ sessions: [SessionState]) -> StateName? {
        sessions.max { $0.ts < $1.ts }?.state
    }

    /// How many sessions are currently `waiting` on the user and not stale.
    /// A session is stale when `now - ts >= ttlSec` (a window closed or crashed while
    /// waiting): waiting is a frozen state — the hook fires once and does not refresh —
    /// so the TTL must be generous enough to survive a genuinely long wait.
    public static func waitingCount(_ sessions: [SessionState], now: Int, ttlSec: Int) -> Int {
        sessions.filter { $0.state == .waiting && now - $0.ts < ttlSec }.count
    }
}
