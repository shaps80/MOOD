import Swift
import Pixl2D

public struct TopPlayerController: Equatable, Sendable {
    /// Horizontal motion model for top-down movement.
    public var horizontal: AxisController

    /// Vertical motion model for top-down movement.
    public var vertical: AxisController

    public init(horizontal: AxisController, vertical: AxisController) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    /// Calculates velocity from an input snapshot.
    ///
    /// This uses `input.direction` directly. Pass `input.normalizedDirection` to
    /// the direction-based overload when diagonals should not move faster.
    public func velocity(for input: Input, current: Vec2, delta: Double) -> Vec2 {
        velocity(for: input.direction, current: current, delta: delta)
    }

    /// Calculates velocity from movement direction.
    ///
    /// Use this for direct game-loop movement code:
    ///
    /// ```swift
    /// state.velocity = controller.velocity(
    ///     for: context.input.normalizedDirection,
    ///     current: state.velocity,
    ///     delta: context.delta
    /// )
    /// ```
    public func velocity(for direction: Vec2, current: Vec2, delta: Double) -> Vec2 {
        Vec2(
            x: horizontal.velocity(
                current: current.x,
                input: direction.x,
                delta: delta
            ),
            y: vertical.velocity(
                current: current.y,
                input: direction.y,
                delta: delta
            )
        )
    }

    public static let `default` = TopPlayerController(
        horizontal: AxisController(
            maxSpeed: 500,
            acceleration: 1500,
            deceleration: 1500
        ),
        vertical: AxisController(
            maxSpeed: 500,
            acceleration: 1500,
            deceleration: 1500
        )
    )

    public static let slippery = TopPlayerController(
        horizontal: AxisController(
            maxSpeed: 600,
            acceleration: 1000,
            deceleration: 1500
        ),
        vertical: AxisController(
            maxSpeed: 300,
            acceleration: 2000,
            deceleration: 2000
        )
    )
}
