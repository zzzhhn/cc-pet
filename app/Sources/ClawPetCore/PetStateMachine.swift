public enum DragDirection: Sendable { case left, right }

public struct PetStateMachine: Sendable {
    private var externalLoop: StateName = .hover   // working/waiting/hover only
    private var typing = false
    private var dragging: DragDirection?
    private var oneShot: StateName?
    public init() {}

    public mutating func setExternal(_ s: StateName) {
        if s.isOneShot {
            oneShot = s
            // greet/cheer/singing are turn-boundary celebrations: once they finish, Claude is
            // idle, so settle the base loop back to hover instead of a stale working/waiting.
            // (droop is a mid-turn error one-shot and must fall back to the ongoing loop.)
            if s == .greet || s == .cheer || s == .singing { externalLoop = .hover }
        } else {
            externalLoop = s
        }
    }
    public mutating func setTyping(_ b: Bool) { typing = b }
    public mutating func setDragging(_ d: DragDirection?) { dragging = d }
    public mutating func triggerInteraction(_ s: StateName) { oneShot = s }   // wave/twirl/hearts
    public mutating func oneShotCompleted() { oneShot = nil }

    /// True only when the pet is showing the default hover idle — the ONLY time a random wave
    /// may fire, so it never interrupts working/waiting/typing/fly/another gesture.
    public var isHoverIdle: Bool { display == .hover }

    /// Priority (high→low): dragging (fly) beats a lingering one-shot, then one-shot,
    /// then typing, then the external Claude-Code loop. Dragging must win over a wave/hearts
    /// one-shot so grabbing the pet flies immediately instead of finishing the gesture.
    public var display: StateName {
        if let d = dragging { return d == .left ? .flyLeft : .flyRight }
        if let o = oneShot { return o }
        if typing { return .typing }
        return externalLoop
    }
}
