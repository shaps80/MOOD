import Swift
import Pixl2D

public struct SidePlayerController: Equatable, Sendable {
    /// Horizontal motion model for side-view movement.
    public var horizontal: AxisController

    public init(horizontal: AxisController) {
        self.horizontal = horizontal
    }

    /// Calculates velocity from an input snapshot.
    public func velocity(for input: Input, current: Vec2, delta: Double) -> Vec2 {
        velocity(for: input.direction, current: current, delta: delta)
    }

    /// Calculates velocity from movement direction.
    ///
    /// The vertical component is ignored because this controller only owns
    /// horizontal movement.
    public func velocity(for direction: Vec2, current: Vec2, delta: Double) -> Vec2 {
        Vec2(
            x: horizontal.velocity(
                current: current.x,
                input: direction.x,
                delta: delta
            ),
            y: current.y
        )
    }

    public static let `default` = SidePlayerController(
        horizontal: AxisController(
            maxSpeed: 300,
            acceleration: 800,
            deceleration: 500
        )
    )
}
