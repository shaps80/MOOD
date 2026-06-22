import Swift

public enum Edge: Sendable {
    case left
    case right
    case top
    case bottom

    public struct Set: OptionSet, Sendable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let left = Set(rawValue: 1 << 0)
        public static let right = Set(rawValue: 1 << 1)
        public static let top = Set(rawValue: 1 << 2)
        public static let bottom = Set(rawValue: 1 << 3)
        public static let horizontal: Set = [.left, .right]
        public static let vertical: Set = [.top, .bottom]
        public static let all: Set = [.horizontal, .vertical]
    }
}
