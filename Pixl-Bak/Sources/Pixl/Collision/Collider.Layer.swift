import Swift

extension Collider {
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

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

public extension Collider.Layer {
    static func + (lhs: Self, rhs: Int) -> Self {
        .init(lhs.rawValue + rhs)
    }

    static func - (lhs: Self, rhs: Int) -> Self {
        .init(lhs.rawValue - rhs)
    }
}

extension Collider.Layer {
    public struct Mask: OptionSet, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public init(_ layer: Collider.Layer) {
            precondition(layer.rawValue >= 0 && layer.rawValue < Int.bitWidth)
            self.rawValue = 1 << layer.rawValue
        }
    }
}
