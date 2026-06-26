import Swift

public struct Layer: RawRepresentable, ExpressibleByIntegerLiteral, Comparable, Hashable, Sendable {
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

    public static func < (lhs: Layer, rhs: Layer) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static let background: Self = .init(0)
    public static let world: Self = .init(100)
    public static let entity: Self = .init(200)
    public static let foreground: Self = .init(300)
    public static let debug: Self = .init(900)
    public static let overlay: Self = .init(1000)
}

public extension Layer {
    static func + (lhs: Layer, rhs: Int) -> Layer {
        Layer(lhs.rawValue + rhs)
    }

    static func - (lhs: Layer, rhs: Int) -> Layer {
        Layer(lhs.rawValue - rhs)
    }
}
