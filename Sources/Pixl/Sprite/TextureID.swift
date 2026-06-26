import Swift

public struct TextureID: Hashable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let player = TextureID(rawValue: "player")
}
