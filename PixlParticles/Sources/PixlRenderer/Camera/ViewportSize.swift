import Swift

public struct ViewportSize: BitwiseCopyable, Sendable {
    public let width: UInt32
    public let height: UInt32

    public init(width: UInt32, height: UInt32) {
        self.width = width
        self.height = height
    }
}
