import Swift

public struct EntityKind: Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: RawValue) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }
}
