import Swift

/// A synchronous, borrowed range job. The context stays alive until execute returns.
/// Each range must have exclusive output storage; inputs may be shared read-only.
public struct SimulationJob: @unchecked Sendable {
    public let count: Int
    private let context: UnsafeRawPointer
    private let body: @Sendable (UnsafeRawPointer, Range<Int>) -> Void

    public init(count: Int, context: UnsafeRawPointer,
                body: @escaping @Sendable (UnsafeRawPointer, Range<Int>) -> Void) {
        self.count = count
        self.context = context
        self.body = body
    }

    public func run(_ range: Range<Int>) {
        body(context, range)
    }
}
