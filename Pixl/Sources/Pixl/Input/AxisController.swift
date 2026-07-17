import Swift
import Pixl2D

/// One-dimensional acceleration and deceleration for axis-based movement.
public struct AxisController: Equatable, Sendable {
    /// Maximum speed reached when input is `-1` or `1`.
    public var maxSpeed: Double

    /// Units per second used while accelerating toward input.
    public var acceleration: Double

    /// Units per second used while returning to rest.
    public var deceleration: Double

    /// Units per second used while changing direction.
    public var reverseDeceleration: Double

    public init(
        maxSpeed: Double,
        acceleration: Double,
        deceleration: Double,
        reverseDeceleration: Double? = nil
    ) {
        self.maxSpeed = maxSpeed
        self.acceleration = acceleration
        self.deceleration = deceleration
        self.reverseDeceleration = reverseDeceleration ?? deceleration
    }

    public func velocity(source: Vec2, target: Vec2, delta: Double) -> Vec2 {
        let x = velocity(source: source.x, target: target.x, delta: delta)
        let y = velocity(source: source.y, target: target.y, delta: delta)
        return .init(x, y)
    }

    /// Calculates the next velocity for a scalar input axis.
    ///
    /// `input` is usually `-1...1`, where negative and positive values move in
    /// opposite directions.
    public func velocity(source: Double, target: Double, delta: Double) -> Double {
        guard target != 0 else {
            return move(source, toward: 0, by: deceleration * delta)
        }

        let target = target * maxSpeed
        if isReversing(current: source, target: target) {
            return move(source, toward: 0, by: reverseDeceleration * delta)
        }

        return move(source, toward: target, by: acceleration * delta)
    }

    private func move(_ current: Double, toward target: Double, by step: Double) -> Double {
        guard step > 0 else {
            return current
        }

        if current < target {
            return min(current + step, target)
        }

        return max(current - step, target)
    }

    private func isReversing(current: Double, target: Double) -> Bool {
        (current < 0 && target > 0) || (current > 0 && target < 0)
    }
}
