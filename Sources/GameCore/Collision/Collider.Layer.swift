import Swift

extension Collider.Layer {
    public static let world: Self = 0
    public static let player: Self = 1
    public static let pickup: Self = 2
    public static let enemy: Self = 3
}

extension Collider.Layer.Mask {
    public static let world = Self(Collider.Layer.world)
    public static let player = Self(Collider.Layer.player)
    public static let pickup = Self(Collider.Layer.pickup)
    public static let enemy = Self(Collider.Layer.enemy)

    static let playerMovement: Self = [.world]
    static let playerInteractions: Self = [.pickup]
    static let enemyMovement: Self = [.world, .player]
}

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
