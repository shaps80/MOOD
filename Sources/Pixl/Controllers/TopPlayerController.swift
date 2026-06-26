import Swift

public struct TopPlayerController: Equatable, Sendable {
    public var horizontal: AxisController
    public var vertical: AxisController

    public init(horizontal: AxisController, vertical: AxisController) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    public func velocity(for input: Input, current: Vec2, delta: Double) -> Vec2 {
        Vec2(
            x: horizontal.velocity(
                current: current.x,
                input: input.horizontal,
                delta: delta
            ),
            y: vertical.velocity(
                current: current.y,
                input: input.vertical,
                delta: delta
            )
        )
    }

    public static let `default` = TopPlayerController(
        horizontal: AxisController(
            maxSpeed: 300,
            acceleration: 2000,
            deceleration: 2000
        ),
        vertical: AxisController(
            maxSpeed: 300,
            acceleration: 2000,
            deceleration: 2000
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
