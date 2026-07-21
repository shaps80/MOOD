import Swift
import Pixl2D

/// One-dimensional acceleration and deceleration for axis-based movement.
public struct AxisController: Equatable, Sendable {
    /// Maximum speed reached when input is `-1` or `1`.
    public var maxSpeed: Float

    /// Units per second used while accelerating toward input.
    public var acceleration: Float

    /// Units per second used while returning to rest.
    public var deceleration: Float

    /// Units per second used while changing direction.
    public var reverseDeceleration: Float

    /// Creates an axis movement controller.
    /// - Parameters:
    ///   - maxSpeed: Speed reached at full input magnitude.
    ///   - acceleration: Units per second added while moving toward input.
    ///   - deceleration: Units per second removed while returning to rest.
    ///   - reverseDeceleration: Units per second removed before changing direction; defaults to `deceleration`.
    public init(
        maxSpeed: Float,
        acceleration: Float,
        deceleration: Float,
        reverseDeceleration: Float? = nil
    ) {
        self.maxSpeed = maxSpeed
        self.acceleration = acceleration
        self.deceleration = deceleration
        self.reverseDeceleration = reverseDeceleration ?? deceleration
    }

    /// Calculates the next two-dimensional velocity component-wise.
    /// - Parameters:
    ///   - source: Current velocity.
    ///   - target: Normalized directional input, usually with components in `-1...1`.
    ///   - delta: Elapsed time in seconds.
    /// - Returns: Velocity after applying acceleration or deceleration for `delta`.
    public func velocity(source: Vec2, target: Vec2, delta: Double) -> Vec2 {
        let x = velocity(source: source.x, target: target.x, delta: delta)
        let y = velocity(source: source.y, target: target.y, delta: delta)
        return .init(x, y)
    }

    /// Calculates the next velocity for a scalar input axis.
    ///
    /// `target` is usually `-1...1`, where negative and positive values move in
    /// opposite directions.
    ///
    /// - Parameters:
    ///   - source: Current scalar velocity.
    ///   - target: Normalized directional input.
    ///   - delta: Elapsed time in seconds.
    /// - Returns: Velocity after applying acceleration or deceleration for `delta`.
    public func velocity(source: Float, target: Float, delta: Double) -> Float {
        let delta = Float(delta)
        guard target != 0 else {
            return move(source, toward: 0, by: deceleration * delta)
        }

        let target = target * maxSpeed
        if isReversing(current: source, target: target) {
            return move(source, toward: 0, by: reverseDeceleration * delta)
        }

        return move(source, toward: target, by: acceleration * delta)
    }

    private func move(_ current: Float, toward target: Float, by step: Float) -> Float {
        guard step > 0 else {
            return current
        }

        if current < target {
            return min(current + step, target)
        }

        return max(current - step, target)
    }

    private func isReversing(current: Float, target: Float) -> Bool {
        (current < 0 && target > 0) || (current > 0 && target < 0)
    }
}
