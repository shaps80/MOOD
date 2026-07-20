import Swift

/// Startup window and presentation preferences supplied by a game.
public struct GameSettings: Sendable, Hashable {
    /// Initial window title.
    public let title: String

    /// Requested presentation rate in frames per second.
    ///
    /// This is a platform preference, not a guarantee. Presentation updates
    /// and rendering may run slower when constrained by display timing or
    /// system load.
    public let preferredFps: Int

    /// Initial drawable resolution.
    public let resolution: SIMD2<Int>

    /// Whether the platform window may be resized.
    public let isResizable: Bool

    /// Creates game startup and presentation preferences.
    ///
    /// - Parameters:
    ///   - title: Initial platform window title.
    ///   - preferredFps: Requested presentation rate. The platform may present
    ///     more slowly when constrained by display timing or system load.
    ///   - resolution: Initial drawable resolution in platform pixels.
    ///   - isResizable: Whether the platform window may be resized.
    public init(
        title: String,
        preferredFps: Int = 60,
        resolution: SIMD2<Int>,
        isResizable: Bool = true
    ) {
        precondition(preferredFps > 0, "Preferred FPS must be greater than zero")
        precondition(resolution.x > 0, "Resolution width must be greater than zero")
        precondition(resolution.y > 0, "Resolution height must be greater than zero")

        self.title = title
        self.resolution = resolution
        self.isResizable = isResizable
        self.preferredFps = preferredFps
    }
}
