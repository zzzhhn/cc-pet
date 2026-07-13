public enum StateName: String, CaseIterable, Sendable {
    case greet, hover, working, typing, waiting, cheer, droop, singing
    case flyLeft = "fly-left"
    case flyRight = "fly-right"
    case wave, twirl, hearts

    public static func parse(_ s: String) -> StateName { StateName(rawValue: s) ?? .hover }

    /// One-shot states play once then revert to the base state.
    public var isOneShot: Bool {
        switch self {
        case .greet, .cheer, .droop, .singing, .wave, .twirl, .hearts: return true
        case .hover, .working, .typing, .waiting, .flyLeft, .flyRight: return false
        }
    }
}
