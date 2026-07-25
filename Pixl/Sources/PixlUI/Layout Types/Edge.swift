import Swift

/// An enumeration to indicate one edge of a rectangle.
@frozen public enum Edge: Int8, CaseIterable, Hashable, RawRepresentable, Sendable {
    case top = 0
    case leading = 1
    case bottom = 2
    case trailing = 3

    /// An efficient set of `Edge`s.
    @frozen public struct Set: OptionSet, Sendable {
        public let rawValue: Int8
        public init(rawValue: Int8) {
            self.rawValue = rawValue
        }

        public static var top: Edge.Set { .init(.top) }
        public static var leading: Edge.Set { .init(.leading) }
        public static var bottom: Edge.Set { .init(.bottom) }
        public static var trailing: Edge.Set { .init(.trailing) }
        public static var all: Edge.Set { [.top, .leading, .bottom, .trailing] }
        public static var horizontal: Edge.Set { [.leading, .trailing] }
        public static var vertical: Edge.Set { [.top, .bottom] }

        /// Creates an instance containing just `e`
        public init(_ e: Edge) {
            self.init(rawValue: Int8(1) << e.rawValue)
        }
    }
}
