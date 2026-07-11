import Swift

/// A rounded viewport for presenting the logical game texture in a container.
///
/// `PresentationViewport` preserves aspect ratio, centers the result, and keeps
/// the final presentation rect on whole pixels.
///
/// ```swift
/// let viewport = PresentationViewport(
///     containerSize: Vec2(x: 1440, y: 900),
///     logicalResolution: Vec2(x: 800, y: 450)
/// )
/// ```
public struct PresentationViewport: Equatable, Sendable {
    /// The pixel-aligned presentation rect inside the container.
    public let rect: Rect

    /// Creates a fitted viewport for a logical game resolution.
    ///
    /// - Parameters:
    ///   - containerSize: The available platform surface size.
    ///   - logicalResolution: The game texture size to present.
    public init(containerSize: Vec2, logicalResolution: Vec2) {
        let scale = min(
            containerSize.x / logicalResolution.x,
            containerSize.y / logicalResolution.y
        )
        let width = max(1, (logicalResolution.x * scale).rounded())
        let height = max(1, (logicalResolution.y * scale).rounded())

        self.rect = Rect(
            x: ((containerSize.x - width) / 2).rounded(),
            y: ((containerSize.y - height) / 2).rounded(),
            width: width,
            height: height
        )
    }
}
