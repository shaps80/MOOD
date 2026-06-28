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
/// update the entity position, then call `worldBounds(at:)` when collision
/// code needs the absolute rect.
public struct Collider: Equatable, Sendable {
    /// Local-space AABB, relative to the owning entity or tile origin.
    public var bounds: Rect
    public var shape: AnyShape
    public var layer: Layer
    public var mask: Layer.Mask
    public var behaviour: Behaviour
    public var oneWay: OneWay?
    private var usesDefaultBounds: Bool

    internal init(
        bounds: Rect,
        shape: AnyShape,
        layer: Layer,
        mask: Layer.Mask,
        behaviour: Behaviour = .blocking,
        oneWay: OneWay? = nil,
        usesDefaultBounds: Bool = false
    ) {
        self.bounds = bounds
        self.shape = shape
        self.layer = layer
        self.mask = mask
        self.behaviour = behaviour
        self.oneWay = oneWay
        self.usesDefaultBounds = usesDefaultBounds
    }

    public init<S: Shape>(
        bounds: Rect,
        shape: S,
        layer: Layer,
        mask: Layer.Mask,
        behaviour: Behaviour = .blocking,
        oneWay: OneWay? = nil
    ) {
        self.init(
            bounds: bounds,
            shape: AnyShape(shape),
            layer: layer,
            mask: mask,
            behaviour: behaviour,
            oneWay: oneWay
        )
    }

    public init(
        bounds: Rect,
        layer: Layer,
        mask: Layer.Mask,
        behaviour: Behaviour = .blocking,
        oneWay: OneWay? = nil
    ) {
        self.init(
            bounds: bounds,
            shape: AnyShape(.rect),
            layer: layer,
            mask: mask,
            behaviour: behaviour,
            oneWay: oneWay
        )
    }

    public init<S: Shape>(
        shape: S,
        layer: Layer,
        mask: Layer.Mask,
        behaviour: Behaviour = .blocking,
        oneWay: OneWay? = nil
    ) {
        self.init(
            bounds: .zero,
            shape: AnyShape(shape),
            layer: layer,
            mask: mask,
            behaviour: behaviour,
            oneWay: oneWay,
            usesDefaultBounds: true
        )
    }

    public init(
        layer: Layer,
        mask: Layer.Mask,
        behaviour: Behaviour = .blocking,
        oneWay: OneWay? = nil
    ) {
        self.init(
            bounds: .zero,
            shape: AnyShape(.rect),
            layer: layer,
            mask: mask,
            behaviour: behaviour,
            oneWay: oneWay,
            usesDefaultBounds: true
        )
    }

    /// Converts center-relative local bounds into world-space bounds at an owner position.
    public func worldBounds(at position: Vec2) -> Rect {
        bounds.translated(by: position)
    }

    public func placed(at position: Vec2) -> Collider {
        var collider = self
        collider.bounds = bounds.translated(by: position)
        return collider
    }

    public func scaled(by scale: Vec2) -> Collider {
        var collider = self
        collider.bounds = bounds.scaled(by: scale)
        return collider
    }

    public func placed(at position: Vec2, scale: Vec2) -> Collider {
        scaled(by: scale).placed(at: position)
    }

    public func placed(at position: Vec2, spriteSize: Vec2, scale: Vec2) -> Collider {
        var collider = self
        let localBounds = usesDefaultBounds ? Rect(size: spriteSize) : bounds
        let scaledOrigin = Vec2(
            x: (localBounds.origin.x - (spriteSize.x / 2)) * scale.x,
            y: (localBounds.origin.y - (spriteSize.y / 2)) * scale.y
        )
        let scaledSize = localBounds.size * scale

        collider.bounds = Rect(origin: scaledOrigin, size: scaledSize)
            .translated(by: position)
        collider.usesDefaultBounds = false

        return collider
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
