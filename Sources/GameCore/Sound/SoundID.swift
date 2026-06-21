import Swift

public struct SoundID: Hashable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let jump = SoundID(rawValue: "jump")
}
