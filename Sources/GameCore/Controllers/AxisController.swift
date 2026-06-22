import Swift

public struct AxisController: Equatable, Sendable {
    public var maxSpeed: Double
    public var acceleration: Double
    public var deceleration: Double
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

    public func velocity(current: Double, input: Double, delta: Double) -> Double {
        guard input != 0 else {
            return move(current, toward: 0, by: deceleration * delta)
        }

        let target = input * maxSpeed
        if isReversing(current: current, target: target) {
            return move(current, toward: 0, by: reverseDeceleration * delta)
        }

        return move(current, toward: target, by: acceleration * delta)
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
