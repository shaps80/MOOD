import Swift

extension RenderLayer {
    public static let background: Self = 0
    public static let world: Self = 100
    public static let entity: Self = 200
    public static let foreground: Self = 300
    public static let debug: Self = 900
    public static let overlay: Self = 1000
}

public struct RenderLayer: RawRepresentable, ExpressibleByIntegerLiteral, Comparable, Hashable, Sendable {
    public var rawValue: Int

    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(integerLiteral value: Int) {
        self.rawValue = value
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public extension RenderLayer {
    static func + (lhs: Self, rhs: Int) -> Self {
        .init(lhs.rawValue + rhs)
    }

    static func - (lhs: Self, rhs: Int) -> Self {
        .init(lhs.rawValue - rhs)
    }
}
