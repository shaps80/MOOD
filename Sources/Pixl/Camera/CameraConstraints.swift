import Swift

/// Restricts where the camera is allowed to move.
///
/// Constraints operate on the base camera origin after anchor, composition, and
/// tracking have chosen a desired origin.
///
/// Resolution:
///
/// ```text
/// desired origin
///      |
///      v
/// apply axis locks
///      |
///      v
/// clamp to bounds
///      |
///      v
/// constrained origin
/// ```
///
/// Bounds clamp diagram:
///
/// ```text
/// level bounds
/// +----------------------------------------+
/// |                                        |
/// |   +------------------------------+     |
/// |   | camera viewport              |     |
/// |   +------------------------------+     |
/// |                                        |
/// +----------------------------------------+
/// ```
///
/// Axis locks are applied before bounds so a locked side-scroller or room
/// camera still respects the world limits.
public struct CameraConstraints: Equatable, Sendable {
    /// Optional world-space bounds that clamp the camera viewport.
    public var bounds: Rect?

    /// Optional fixed world-space X origin.
    public var lockX: Double?

    /// Optional fixed world-space Y origin.
    public var lockY: Double?

    /// Creates camera constraints.
    ///
    /// - Parameters:
    ///   - bounds: Optional world-space bounds that clamp the viewport.
    ///   - lockX: Optional fixed world-space X origin.
    ///   - lockY: Optional fixed world-space Y origin.
    public init(
        bounds: Rect? = nil,
        lockX: Double? = nil,
        lockY: Double? = nil
    ) {
        self.bounds = bounds
        self.lockX = lockX
        self.lockY = lockY
    }

    func constrain(origin: Vec2, viewportSize: Vec2) -> Vec2 {
        var origin = origin

        if let lockX {
            origin = Vec2(x: lockX, y: origin.y)
        }

        if let lockY {
            origin = Vec2(x: origin.x, y: lockY)
        }

        guard let bounds else {
            return origin
        }

        let maxX = max(bounds.minX, bounds.maxX - viewportSize.x)
        let maxY = max(bounds.minY, bounds.maxY - viewportSize.y)

        return Vec2(
            x: clamp(origin.x, min: bounds.minX, max: maxX),
            y: clamp(origin.y, min: bounds.minY, max: maxY)
        )
    }
}
