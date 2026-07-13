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
}
