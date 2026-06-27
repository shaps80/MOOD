import Swift

/// Controls how the selected anchor is framed inside the viewport.
///
/// The anchor finds the subject. Composition shifts the framing around that
/// subject before constraints and effects are applied.
///
/// Current implementation:
///
/// ```text
/// desired origin = anchor center - half viewport + offset
/// ```
///
/// Example:
///
/// ```text
/// no offset                         positive x offset
/// +--------------+                  +--------------+
/// |      *       |                  |   *          |
/// |              |                  |              |
/// +--------------+                  +--------------+
///
/// * = anchor center
/// ```
///
/// Future composition options can include lookahead, dead zones, and horizontal
/// or vertical bias without changing renderer behavior.
public struct CameraComposition: Equatable, Sendable {
    /// World-space offset applied while placing the anchor in the viewport.
    public var offset: Vec2

    /// Creates camera composition settings.
    ///
    /// - Parameter offset: World-space offset applied to the framed anchor.
    public init(offset: Vec2) {
        self.offset = offset
    }

    public init(x: Double = 0, y: Double = 0) {
        self.offset = .init(x: x, y: y)
    }
}
