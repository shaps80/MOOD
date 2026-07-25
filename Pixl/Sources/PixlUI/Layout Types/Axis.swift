import Swift

/// The horizontal or vertical dimension in a 2D coordinate system.
@frozen public enum Axis: Int8, CaseIterable, Hashable, RawRepresentable, Sendable {
    /// The horizontal dimension.
    case horizontal = 0
    /// The vertical dimension.
    case vertical = 1

    /// An efficient set of axes.
    @frozen public struct Set: OptionSet, Sendable {
        public typealias Element = Axis.Set
        public let rawValue: Int8
        public init(rawValue: Int8) {
            self.rawValue = rawValue
        }

        public static var horizontal: Axis.Set { .init(rawValue: Axis.horizontal.rawValue) }
        public static var vertical: Axis.Set { .init(rawValue: Axis.vertical.rawValue) }
        public typealias RawValue = Int8
    }
}
