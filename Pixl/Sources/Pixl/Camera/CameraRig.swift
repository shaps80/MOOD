import Swift

/// Resolves gameplay-facing camera behavior into the final camera viewport.
///
/// `CameraRig` owns camera behavior. It turns an anchor, tracking mode,
/// constraints, and transform into the final camera state consumed by renderers.
///
/// Parts:
///
/// ```text
/// anchor       what to frame
/// tracking     how to move toward it
/// constraints  where movement is allowed
/// transform    viewport-centered presentation transform
/// ```
///
/// Resolution order:
///
/// ```text
/// anchor center
///      |
///      v
/// desired origin = center - half viewport
///      |
///      v
/// tracking.resolve(current, desired, delta)
///      |
///      v
/// constraints.constrain(origin)
///      |
///      v
/// camera.origin
///
/// transform is applied later during render planning
/// ```
///
/// Renderer rule stays boring:
///
/// ```text
/// screenPosition = cameraTransform(worldPosition - camera.origin)
/// ```
public struct CameraRig: Equatable, Sendable {
    /// The final resolved camera viewport.
    public private(set) var camera: Camera

    /// The point or entities the camera should frame.
    public var anchor: CameraAnchor

    /// The movement policy used to approach the desired origin.
    public var tracking: CameraTracking

    /// Viewport-centered presentation transform applied after base camera
    /// resolution.
    ///
    /// This transform is deliberately separate from `camera.origin`. The anchor,
    /// tracking, and constraints resolve the stable world-space viewport first;
    /// then render planning applies this transform around the viewport center.
    ///
    /// Use `position` for pan or shake offsets, `scale` for zoom, and `rotation`
    /// for camera roll. These values affect presentation only: they do not feed
    /// back into collision, entity positions, anchor resolution, or constraints.
    public var transform: Transform

    /// Movement limits applied before the presentation transform.
    public var constraints: CameraConstraints

    /// Creates a camera rig.
    ///
    /// - Parameters:
    ///   - camera: Initial resolved camera viewport.
    ///   - anchor: The point or entities to frame.
    ///   - tracking: Movement policy used to approach the desired origin.
    ///   - transform: Viewport-centered presentation transform.
    ///   - constraints: Movement limits applied before the presentation transform.
    public init(
        camera: Camera,
        anchor: CameraAnchor,
        tracking: CameraTracking = .smooth(speed: 900),
        transform: Transform = .identity,
        constraints: CameraConstraints? = .init()
    ) {
        self.camera = camera
        self.anchor = anchor
        self.tracking = tracking
        self.transform = transform
        self.constraints = constraints ?? .init(bounds: nil)
    }

    /// Resolves the camera for the current frame.
    ///
    /// `anchorBounds` is supplied by game state so Pixl can stay independent of
    /// gameplay entity types. `delta` lets tracking modes move over time. If the
    /// current anchor cannot resolve to a point, the camera keeps its previous
    /// resolved state.
    ///
    /// - Parameter delta: Elapsed simulation time for this update.
    /// - Parameter anchorBounds: Looks up world-space bounds for an entity ID.
    public mutating func update(delta: Double, anchorBounds: (EntityID) -> Rect?) {
        guard let anchorCenter = anchor.center(anchorBounds: anchorBounds) else {
            return
        }

        var origin = Vec2(
            x: anchorCenter.x - (camera.viewportSize.x / 2),
            y: anchorCenter.y - (camera.viewportSize.y / 2)
        )

        origin = tracking.resolve(
            current: camera.origin,
            desired: origin,
            delta: delta
        )
        origin = constraints.constrain(origin: origin, viewportSize: camera.viewportSize)

        camera.origin = origin
    }

    var resolvedTransform: Transform {
        transform
    }
}
