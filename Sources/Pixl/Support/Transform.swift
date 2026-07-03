import Swift

/// Position, rotation, and scale for game objects in Pixl's y-down coordinate space.
///
/// Use `Transform` anywhere gameplay needs to place, rotate, or scale an entity,
/// sprite, collider, or other game-facing object.
///
/// Pixl stores these values directly because they are easy to reason about in
/// game code. Collision and rendering code can derive an internal affine matrix
/// when point transformation or parent-child composition needs matrix math.
///
/// ```swift
/// state.transform.position = Vec2(x: 100, y: 80)
/// state.transform.rotation += .degrees(45)
/// state.transform.scale = Vec2(x: 2, y: 2)
/// ```
public struct Transform: Equatable, Hashable, Codable, Sendable {
    /// The local or world-space position.
    ///
    /// For entities this is world-space. For sprites and colliders this is local
    /// to the owning entity transform.
    public var position: Vec2

    /// The clockwise rotation in y-down coordinates.
    public var rotation: Angle

    /// The horizontal and vertical scale.
    public var scale: Vec2

    /// Creates a transform from position, rotation, and scale components.
    ///
    /// Defaults produce the identity transform: zero position, zero rotation,
    /// and one-to-one scale.
    public init(
        position: Vec2 = .zero,
        rotation: Angle = .zero,
        scale: Vec2 = .one
    ) {
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }

    /// A transform that leaves points unchanged.
    public static let identity = Transform()

    /// Returns this transform composed with a child-local transform.
    ///
    /// The result is suitable for rendering or broad gameplay logic that needs a
    /// child object's world transform.
    ///
    /// ```swift
    /// let spriteWorldTransform = entityTransform.concatenated(with: sprite.transform)
    /// ```
    public func concatenated(with child: Transform) -> Transform {
        return Transform(
            position: TransformMatrix(self).applying(to: child.position),
            rotation: rotation + child.rotation,
            scale: scale * child.scale
        )
    }
}

struct TransformMatrix: Equatable, Sendable {
    var a: Double
    var b: Double
    var c: Double
    var d: Double
    var tx: Double
    var ty: Double

    init(_ transform: Transform) {
        let components = sincos(transform.rotation)

        a = components.cos * transform.scale.x
        b = components.sin * transform.scale.x
        c = -components.sin * transform.scale.y
        d = components.cos * transform.scale.y
        tx = transform.position.x
        ty = transform.position.y
    }

    init(
        a: Double,
        b: Double,
        c: Double,
        d: Double,
        tx: Double,
        ty: Double
    ) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }

    func concatenated(with child: TransformMatrix) -> TransformMatrix {
        TransformMatrix(
            a: (a * child.a) + (c * child.b),
            b: (b * child.a) + (d * child.b),
            c: (a * child.c) + (c * child.d),
            d: (b * child.c) + (d * child.d),
            tx: (a * child.tx) + (c * child.ty) + tx,
            ty: (b * child.tx) + (d * child.ty) + ty
        )
    }

    func applying(to point: Vec2) -> Vec2 {
        Vec2(
            x: (a * point.x) + (c * point.y) + tx,
            y: (b * point.x) + (d * point.y) + ty
        )
    }
}
