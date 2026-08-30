import Pixl2D

/// Input captured by ``PlatformerController`` independently of physical bindings.
public struct PlatformerInput: Equatable, Sendable {
    /// Directional input. Horizontal movement uses `x`; dashing may also use `y`.
    public var movement: Vec2
    public var jump: PlatformerButtonInput
    public var run: PlatformerButtonInput
    public var dash: PlatformerButtonInput
    public var crouch: PlatformerButtonInput

    public init(
        movement: Vec2 = .zero,
        jump: PlatformerButtonInput = .init(),
        run: PlatformerButtonInput = .init(),
        dash: PlatformerButtonInput = .init(),
        crouch: PlatformerButtonInput = .init()
    ) {
        self.movement = movement
        self.jump = jump
        self.run = run
        self.dash = dash
        self.crouch = crouch
    }
}
