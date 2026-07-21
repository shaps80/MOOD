/// Repeated staircase geometry.
public struct Stairs: Hashable, Sendable {
    /// Width and height of one step.
    public let stepSize: Vec2
    /// Number of repeated steps.
    public let count: UInt32
    /// Creates four canonical unit steps.
    public init() { self.init(stepSize: .init(0.25, 0.25), count: 4) }
    /// Creates a staircase.
    /// - Parameters:
    ///   - stepSize: Positive finite width and height of one step.
    ///   - count: Positive number of steps.
    public init(stepSize: Vec2, count: UInt32) {
        precondition(stepSize.x.isFinite && stepSize.x > 0 && stepSize.y.isFinite && stepSize.y > 0)
        precondition(count > 0)
        self.stepSize = stepSize; self.count = count
    }
    /// Four canonical unit steps.
    public static var stairs: Self { .init() }
    /// Staircase geometry with explicit step dimensions and count.
    /// - Parameters:
    ///   - stepSize: Positive width and height of one step.
    ///   - count: Positive number of steps.
    public static func stairs(stepSize: Vec2, count: UInt32) -> Self { .init(stepSize: stepSize, count: count) }
}
