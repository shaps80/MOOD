import Swift

/// A platform-neutral snapshot of player input for one update.
///
/// Platform adapters translate keyboard, touch, or gamepad state into `Input`;
/// Pixl consumes only this shape.
///
/// ```swift
/// let keyboard = Input(horizontal: 1, jump: true)
/// let gamepad = Input(horizontal: 0.25)
/// let input = keyboard.combined(with: gamepad)
/// ```
public struct Input: Equatable, Sendable {
    /// Horizontal movement intent, usually from `-1...1`.
    ///
    /// ```swift
    /// let input = Input(horizontal: -1)
    /// let xAxis = input.horizontal
    /// ```
    public let horizontal: Double

    /// Vertical movement intent, usually from `-1...1`.
    ///
    /// ```swift
    /// let input = Input(vertical: 1)
    /// let yAxis = input.vertical
    /// ```
    public let vertical: Double

    /// Whether the jump action is pressed.
    ///
    /// ```swift
    /// let input = Input(jump: true)
    /// if input.jump { /* start jump */ }
    /// ```
    public let jump: Bool

    /// Whether the reset action is pressed.
    ///
    /// ```swift
    /// let input = Input(reset: true)
    /// if input.reset { /* reload level */ }
    /// ```
    public let reset: Bool

    /// Creates an input snapshot.
    ///
    /// Omitted values default to neutral axes and unpressed actions.
    ///
    /// ```swift
    /// let idle = Input()
    /// let moveRight = Input(horizontal: 1)
    /// ```
    public init(
        horizontal: Double = 0,
        vertical: Double = 0,
        jump: Bool = false,
        reset: Bool = false
    ) {
        self.horizontal = horizontal
        self.vertical = vertical
        self.jump = jump
        self.reset = reset
    }

    /// Combines two input snapshots, clamping axes and merging pressed actions.
    ///
    /// Use this when multiple devices can drive the same player.
    ///
    /// ```swift
    /// let keyboard = Input(horizontal: 1)
    /// let touch = Input(horizontal: 0.5, jump: true)
    /// let input = keyboard.combined(with: touch)
    /// ```
    public func combined(with other: Input) -> Input {
        Input(
            horizontal: clamp(horizontal + other.horizontal, min: -1, max: 1),
            vertical: clamp(vertical + other.vertical, min: -1, max: 1),
            jump: jump || other.jump,
            reset: reset || other.reset
        )
    }
}
