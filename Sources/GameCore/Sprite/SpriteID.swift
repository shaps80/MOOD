import Swift

public struct SpriteID: Hashable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let player = SpriteID(rawValue: "player")
}
