import Swift

/// An edge of a rectangle using layout-aware horizontal terminology.
@frozen public enum Edge: Int8, CaseIterable, Hashable, Sendable {
    case top
    case leading
    case bottom
    case trailing

    @frozen public struct Set: OptionSet, Hashable, Sendable {
        public let rawValue: Int8

        public init(rawValue: Int8) {
            self.rawValue = rawValue
        }

        public static let top: Self = .init(.top)
        public static let leading: Self = .init(.leading)
        public static let bottom: Self = .init(.bottom)
        public static let trailing: Self = .init(.trailing)
        public static let all: Self = [.top, .leading, .bottom, .trailing]
        public static let horizontal: Self = [.leading, .trailing]
        public static let vertical: Self = [.top, .bottom]

        public init(_ edge: Edge) {
            self.init(rawValue: 1 << edge.rawValue)
        }
    }
}
