import Swift

/// A diagnosed PixlMemory operation failure.
public struct MemoryFailure: Error, CustomStringConvertible, Sendable {
    public let description: String

    init(_ description: String) {
        self.description = description
    }
}
