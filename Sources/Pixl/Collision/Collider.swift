import Swift

/// Axis-aligned collision bounds attached to something in the world.
///
/// A collider stores bounds in **local space**. Local space means the rect is
/// relative to the owner, not the whole world.
///
/// Example: player entity at world position `(100, 40)`.
///
/// ```text
/// World space
///
///   x=100
///     |
///     v
///     +---------------- entity ----------------+
///     |                                        |
///     |   collider bounds: (4, 8, 24, 20)      |
///     |                                        |
///     +----------------------------------------+
///
/// Local collider:
///   minX = 4, maxX = 28
///   minY = 8, maxY = 28
///
/// World collider:
///   minX = 104, maxX = 128
///   minY = 48,  maxY = 68
/// ```
///
/// Keeping bounds local makes the collider move with its owner automatically:
/// update the owner transform, then collision code places the collider into
/// world space for broad and narrow phase checks.
public struct Collider: Equatable, Sendable {
    /// Local-space AABB before placement; broad-phase world AABB after placement.
    public var bounds: Rect
    public var shape: AnyShape
    public var layer: Layer
    public var mask: Layer.Mask
    public var behaviour: Behaviour
    public var oneWay: OneWay?
    public var transform: Transform

    /// Tangential drag applied when resolving blocking movement.
    ///
    /// `0` preserves more speed along the surface, `1` uses plain projection,
    /// and values above `1` add extra slowdown.
    ///
    /// ```swift
    /// Collider(bounds: rampBounds, layer: .world, mask: .player, friction: 0.25)
    /// ```
    public var friction: Double
    private var usesDefaultBounds: Bool
    var shapeFrame: Rect
    var rotation: Angle
    var points: [Vec2]

    internal init(
        bounds: Rect,
        shape: AnyShape,
        layer: Layer,
        mask: Layer.Mask,
        behaviour: Behaviour = .blocking,
        oneWay: OneWay? = nil,
        transform: Transform = .identity,
        friction: Double = 1,
        usesDefaultBounds: Bool = false
    ) {
        self.bounds = bounds
        self.shape = shape
        self.layer = layer
        self.mask = mask
        self.behaviour = behaviour
        self.oneWay = oneWay
        self.transform = transform
        self.friction = friction
        self.usesDefaultBounds = usesDefaultBounds
        self.shapeFrame = bounds
        self.rotation = .zero
        self.points = []
    }

    public init<S: Shape>(
        bounds: Rect,
        shape: S,
        layer: Layer,
        mask: Layer.Mask,
        behaviour: Behaviour = .blocking,
        oneWay: OneWay? = nil,
        transform: Transform = .identity,
        friction: Double = 1
    ) {
        self.init(
            bounds: bounds,
            shape: AnyShape(shape),
            layer: layer,
            mask: mask,
            behaviour: behaviour,
            oneWay: oneWay,
            transform: transform,
            friction: friction
        )
    }

    public init(
        bounds: Rect,
        layer: Layer,
        mask: Layer.Mask,
        behaviour: Behaviour = .blocking,
        oneWay: OneWay? = nil,
        transform: Transform = .identity,
        friction: Double = 1
    ) {
        self.init(
            bounds: bounds,
            shape: AnyShape(.rect),
            layer: layer,
            mask: mask,
            behaviour: behaviour,
            oneWay: oneWay,
            transform: transform,
            friction: friction
        )
    }

    public init<S: Shape>(
        shape: S,
        layer: Layer,
        mask: Layer.Mask,
        behaviour: Behaviour = .blocking,
        oneWay: OneWay? = nil,
        transform: Transform = .identity,
        friction: Double = 1
    ) {
        self.init(
            bounds: .zero,
            shape: AnyShape(shape),
            layer: layer,
            mask: mask,
            behaviour: behaviour,
            oneWay: oneWay,
            transform: transform,
            friction: friction,
            usesDefaultBounds: true
        )
    }

    public init(
        layer: Layer,
        mask: Layer.Mask,
        behaviour: Behaviour = .blocking,
        oneWay: OneWay? = nil,
        transform: Transform = .identity,
        friction: Double = 1
    ) {
        self.init(
            bounds: .zero,
            shape: AnyShape(.rect),
            layer: layer,
            mask: mask,
            behaviour: behaviour,
            oneWay: oneWay,
            transform: transform,
            friction: friction,
            usesDefaultBounds: true
        )
    }

    func placed(at position: Vec2) -> Collider {
        var collider = self
        collider.shapeFrame = shapeFrame.translated(by: position)
        collider.bounds = collider.shapeFrame.rotatedBounds(rotation)
        collider.points = shape.collisionPoints(in: collider.shapeFrame)
        return collider
    }

    func placed(
        in ownerTransform: Transform,
        spriteSize: Vec2
    ) -> Collider {
        var collider = self
        let localBounds = usesDefaultBounds ? Rect(size: spriteSize) : bounds
        let scaledOrigin = Vec2(
            x: localBounds.origin.x - (spriteSize.x / 2),
            y: localBounds.origin.y - (spriteSize.y / 2)
        )
        let localFrame = Rect(origin: scaledOrigin, size: localBounds.size)
        let matrix = TransformMatrix(ownerTransform)
            .concatenated(with: TransformMatrix(transform))
        let points = collider.shape.collisionPoints(in: localFrame)
            .map { matrix.applying(to: $0) }
        let worldTransform = ownerTransform.concatenated(with: transform)

        collider.shapeFrame = Rect(
            center: matrix.applying(to: localFrame.center),
            size: localFrame.size * worldTransform.scale
        )
        collider.rotation = worldTransform.rotation
        collider.bounds = Rect(enclosing: points)
        collider.points = points
        collider.usesDefaultBounds = false

        return collider
    }
}

extension Rect {
    init(enclosing points: [Vec2]) {
        guard let first = points.first else {
            self = .zero
            return
        }

        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y

        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        self.init(
            x: minX,
            y: minY,
            width: max(0, maxX - minX),
            height: max(0, maxY - minY)
        )
    }

    func rotatedBounds(_ rotation: Angle) -> Rect {
        let corners = [
            Vec2(x: minX, y: minY),
            Vec2(x: maxX, y: minY),
            Vec2(x: maxX, y: maxY),
            Vec2(x: minX, y: maxY)
        ]
        let center = center
        let rotated = corners.map { $0.rotated(around: center, by: rotation) }
        let minX = rotated.map(\.x).min() ?? center.x
        let maxX = rotated.map(\.x).max() ?? center.x
        let minY = rotated.map(\.y).min() ?? center.y
        let maxY = rotated.map(\.y).max() ?? center.y

        return Rect(
            x: minX,
            y: minY,
            width: max(0, maxX - minX),
            height: max(0, maxY - minY)
        )
    }
}

extension Vec2 {
    func rotated(around center: Vec2, by rotation: Angle) -> Vec2 {
        let components = sincos(rotation)
        let local = self - center

        return Vec2(
            x: center.x + (local.x * components.cos) - (local.y * components.sin),
            y: center.y + (local.x * components.sin) + (local.y * components.cos)
        )
    }
}

extension Collider {
    public enum Behaviour: Equatable, Sendable {
        case blocking
        case trigger
    }

    public enum Face: Equatable, Sendable {
        case top
        case bottom
        case left
        case right
    }

    public struct OneWay: Equatable, Sendable {
        public var face: Face
        public var margin: Double

        public init(face: Face = .top, margin: Double = 0) {
            self.face = face
            self.margin = margin
        }
    }
}
