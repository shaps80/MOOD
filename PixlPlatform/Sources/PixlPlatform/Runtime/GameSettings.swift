import Swift

/// Initial drawable resolution in platform pixels.
public struct Resolution: Sendable, Hashable {
    /// Initial drawable width in pixels.
    public let width: Int

    /// Initial drawable height in pixels.
    public let height: Int

    /// Creates an initial drawable resolution.
    ///
    /// - Parameters:
    ///   - width: Initial drawable width in platform pixels.
    ///   - height: Initial drawable height in platform pixels.
    public init(width: Int, height: Int) {
        precondition(width > 0, "Resolution width must be greater than zero")
        precondition(height > 0, "Resolution height must be greater than zero")

        self.width = width
        self.height = height
    }
}

/// Startup window and presentation preferences supplied by a game.
public struct GameSettings: Sendable, Hashable {
    /// Initial window title.
    public let title: String

    /// Requested presentation rate in frames per second.
    ///
    /// This is a platform preference, not a guarantee. Actual presentation
    /// callbacks—and therefore ``Game/update(_:lanes:)`` and rendering—may run
    /// slower when constrained by display timing or system load.
    public let preferredFps: Int

    /// Initial drawable resolution.
    public let resolution: Resolution

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
        resolution: Resolution,
        isResizable: Bool = false
    ) {
        precondition(preferredFps > 0, "Preferred FPS must be greater than zero")

        self.title = title
        self.resolution = resolution
        self.isResizable = isResizable
        self.preferredFps = preferredFps
    }
}
