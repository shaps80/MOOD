import Swift

public struct CameraRig: Equatable, Sendable {
    public private(set) var camera: Camera
    public var anchor: CameraAnchor
    public var tracking: CameraTracking
    public var composition: CameraComposition
    public var constraints: CameraConstraints
    public var effects: CameraEffects

    public init(
        camera: Camera,
        anchor: CameraAnchor,
        tracking: CameraTracking = .snap,
        composition: CameraComposition = .init(),
        constraints: CameraConstraints = .init(),
        effects: CameraEffects = .init()
    ) {
        self.camera = camera
        self.anchor = anchor
        self.tracking = tracking
        self.composition = composition
        self.constraints = constraints
        self.effects = effects
    }

    public mutating func update(anchorBounds: (EntityID) -> Rect?) {
        guard let anchorCenter = anchor.center(anchorBounds: anchorBounds) else {
            return
        }

        var origin = Vec2(
            x: anchorCenter.x - (camera.viewportSize.x / 2) + composition.offset.x,
            y: anchorCenter.y - (camera.viewportSize.y / 2) + composition.offset.y
        )

        origin = tracking.resolve(current: camera.origin, desired: origin)
        origin = constraints.constrain(origin: origin, viewportSize: camera.viewportSize)
        origin = Vec2(
            x: origin.x + effects.offset.x,
            y: origin.y + effects.offset.y
        )

        camera.origin = origin
    }
}
