import Swift

extension Edge {
    @frozen public enum Corner: Int8, Hashable, CaseIterable, Sendable {
        case topLeading
        case topTrailing
        case bottomLeading
        case bottomTrailing

        @frozen public struct Set: OptionSet, Hashable, Sendable {
            public var rawValue: Int8

            public init(rawValue: Int8) {
                self.rawValue = rawValue
            }

            public static let none: Self = []
            public static let topLeading: Self = .init(rawValue: 1 << 0)
            public static let topTrailing: Self = .init(rawValue: 1 << 1)
            public static let bottomLeading: Self = .init(rawValue: 1 << 2)
            public static let bottomTrailing: Self = .init(rawValue: 1 << 3)
            public static let all: Self = [.topLeading, .topTrailing, .bottomLeading, .bottomTrailing]
            public static let leading: Self = [.topLeading, .bottomLeading]
            public static let trailing: Self = [.topTrailing, .bottomTrailing]
            public static let top: Self = [.topLeading, .topTrailing]
            public static let bottom: Self = [.bottomLeading, .bottomTrailing]

            public init(_ corner: Edge.Corner) {
                self.init(rawValue: 1 << corner.rawValue)
            }
        }
    }
}

extension Edge.Corner {
    /// A style that describes the corner of a rectangular shape.
    public struct Style: Sendable, Hashable {
        package indirect enum Storage: Sendable, Hashable {
            case fixed(Float)
            case concentric(minimum: Style?)
        }

        package let storage: Storage

        package init(storage: Storage) {
            self.storage = storage
        }

        public static func fixed(_ radius: Float) -> Self {
            .init(storage: .fixed(max(0, radius)))
        }

        public static var concentric: Self {
            .init(storage: .concentric(minimum: nil))
        }

        public static func concentric(minimum: Self? = nil) -> Self {
            .init(storage: .concentric(minimum: minimum))
        }
    }
}

extension Edge.Corner.Style: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Float) {
        self = .fixed(value)
    }
}

extension Edge.Corner.Style: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .fixed(Float(value))
    }
}
