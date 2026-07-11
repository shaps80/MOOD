import Swift

public struct Resolution: Sendable, Hashable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        precondition(width > 0, "Resolution width must be greater than zero")
        precondition(height > 0, "Resolution height must be greater than zero")

        self.width = width
        self.height = height
    }
}

public struct GameSettings: Sendable, Hashable {
    public let title: String
    public let preferredFps: Int
    public let resolution: Resolution
    public let isResizable: Bool

    public init(
        title: String,
        preferredFps: Int = 60,
        resolution: Resolution,
        isResizable: Bool = true
    ) {
        precondition(preferredFps > 0, "Preferred FPS must be greater than zero")

        self.title = title
        self.resolution = resolution
        self.isResizable = isResizable
        self.preferredFps = preferredFps
    }
}
