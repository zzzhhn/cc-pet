public struct CellSize: Codable, Equatable, Sendable { public let w: Int; public let h: Int }

public struct StateSpec: Codable, Equatable, Sendable {
    public let name: String
    public let row: Int
    public let frames: Int
    public let durations: [Int]   // milliseconds per frame
    public let loop: Bool
}

public struct PetManifest: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let spritesheetPath: String
    public let cell: CellSize
    public let states: [StateSpec]
    /// Optional hex (e.g. "#78C0C0") for the collapsed bubble's pixel body. Optional so
    /// existing manifests decode unchanged; the app falls back to a default teal when absent.
    public let accentColor: String?
    public func state(_ name: StateName) -> StateSpec? { states.first { $0.name == name.rawValue } }
}
