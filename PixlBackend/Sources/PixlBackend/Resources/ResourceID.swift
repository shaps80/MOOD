import Swift

public struct ResourceID: Hashable, Sendable {
    public let rawValue: UInt64

    package init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }
}
