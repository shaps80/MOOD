import Swift

public struct SidePlayerController: Equatable, Sendable {
    public var horizontal: AxisController

    public init(horizontal: AxisController) {
        self.horizontal = horizontal
    }

    public func velocity(for input: Input, current: Vec2, delta: Double) -> Vec2 {
        Vec2(
            x: horizontal.velocity(
                current: current.x,
                input: input.horizontal,
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
