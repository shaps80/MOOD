import PixlInput

/// One presentation-frame button snapshot consumed by ``PlatformerController``.
public struct PlatformerButtonInput: Equatable, Sendable {
    public var isHeld: Bool
    public var wasPressed: Bool
    public var wasReleased: Bool

    public init(
        isHeld: Bool = false,
        wasPressed: Bool = false,
        wasReleased: Bool = false
    ) {
        self.isHeld = isHeld
        self.wasPressed = wasPressed
        self.wasReleased = wasReleased
    }

    /// Creates a button snapshot from one resolved semantic input.
    public init(_ input: Input) {
        self.init(
            isHeld: input.value > 0,
            wasPressed: input.is(.down),
            wasReleased: input.is(.up)
        )
    }
}
