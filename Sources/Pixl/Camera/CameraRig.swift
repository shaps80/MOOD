import Swift

/// Resolves gameplay-facing camera behavior into the final camera viewport.
///
/// `CameraRig` owns camera behavior. It turns an anchor, tracking mode,
/// composition, constraints, and effects into the final `Camera` consumed by
/// renderers.
///
/// Parts:
///
/// ```text
/// anchor       what to frame
/// composition  how to frame it
/// tracking     how to move toward it
/// constraints  where movement is allowed
/// effects      presentation-only offsets
/// ```
///
/// Resolution order:
///
/// ```text
/// anchor center
///      |
///      v
/// desired origin = center - half viewport + composition offset
///      |
///      v
/// tracking.resolve(current, desired, delta)
///      |
///      v
/// constraints.constrain(origin)
///      |
///      v
/// origin + effects.offset
///      |
///      v
/// camera.origin
/// ```
///
/// Renderer rule stays boring:
///
/// ```text
/// screenPosition = worldPosition - camera.origin
/// ```
public struct CameraRig: Equatable, Sendable {
    /// The final resolved camera viewport.
    public private(set) var camera: Camera

    /// The point or entities the camera should frame.
    public var anchor: CameraAnchor

    /// The movement policy used to approach the desired origin.
    public var tracking: CameraTracking

    /// Framing adjustments applied around the anchor.
    public var composition: CameraComposition

    /// Movement limits applied before final effects.
    public var constraints: CameraConstraints

    /// Presentation-only offsets applied last.
    public var effects: CameraEffects

    /// Creates a camera rig.
    ///
    /// - Parameters:
    ///   - camera: Initial resolved camera viewport.
    ///   - anchor: The point or entities to frame.
    ///   - tracking: Movement policy used to approach the desired origin.
    ///   - composition: Framing adjustments applied around the anchor.
    ///   - constraints: Movement limits applied before final effects.
    ///   - effects: Presentation-only offsets applied last.
    public init(
        camera: Camera,
        anchor: CameraAnchor,
        tracking: CameraTracking = .smooth(speed: 900),
        composition: CameraComposition = .init(),
        constraints: CameraConstraints? = .init(),
        effects: CameraEffects = .init()
    ) {
        self.camera = camera
        self.anchor = anchor
        self.tracking = tracking
        self.composition = composition
        self.constraints = constraints ?? .init(bounds: nil)
        self.effects = effects
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
            x: anchorCenter.x - (camera.viewportSize.x / 2) + composition.offset.x,
            y: anchorCenter.y - (camera.viewportSize.y / 2) + composition.offset.y
        )

        origin = tracking.resolve(
            current: camera.origin,
            desired: origin,
            delta: delta
        )
        origin = constraints.constrain(origin: origin, viewportSize: camera.viewportSize)
        origin = Vec2(
            x: origin.x + effects.offset.x,
            y: origin.y + effects.offset.y
        )

        camera.origin = origin
    }
}
