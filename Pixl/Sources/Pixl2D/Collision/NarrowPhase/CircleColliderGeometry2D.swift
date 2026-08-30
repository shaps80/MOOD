import Swift

/// Collision-ready world-space lowering of one immutable local-space circle.
final class CircleColliderGeometry2D {
    let geometry: Circle2D

    private(set) var center = Vec2.zero
    private(set) var radius: Float = 0
    private(set) var bounds = Rect.invalid
    private var pendingTransform: Transform2D

    init(_ circle: Circle2D, transform: Transform2D) {
        geometry = circle
        pendingTransform = transform
        synchronize()
    }

    @discardableResult
    func setTransform(_ transform: Transform2D) -> Bool {
        guard pendingTransform.differs(from: transform) else { return false }
        pendingTransform = transform
        return true
    }

    func synchronize() {
        let scale = pendingTransform.analyticCollisionScale
        center = pendingTransform.transformed(point: geometry.center)
        radius = geometry.radius * scale
        bounds = Rect(
            center: center,
            size: .init(repeating: radius * 2)
        )
    }

    /// Returns a contact directed from `rect` toward this circle.
    func contact(from rect: Rect) -> Contact2D? {
        var test = SeparatingAxisContact2D()
        let horizontal = Vec2(1, 0)
        let vertical = Vec2(0, 1)
        guard test.include(
            axis: horizontal,
            source: .init(rect: rect, axis: horizontal),
            target: .init(circle: self, axis: horizontal),
            canResolve: true
        ), test.include(
            axis: vertical,
            source: .init(rect: rect, axis: vertical),
            target: .init(circle: self, axis: vertical),
            canResolve: true
        ) else { return nil }

        let closest = Vec2(
            Swift.max(rect.minX, Swift.min(center.x, rect.maxX)),
            Swift.max(rect.minY, Swift.min(center.y, rect.maxY))
        )
        let cornerAxis = (center - closest).normalized
        if cornerAxis != .zero,
           !test.include(
                axis: cornerAxis,
                source: .init(rect: rect, axis: cornerAxis),
                target: .init(circle: self, axis: cornerAxis),
                canResolve: true
           ) {
            return nil
        }
        return test.contact
    }

    /// Returns a contact directed from `other` toward this circle.
    func contact(from other: CircleColliderGeometry2D) -> Contact2D? {
        let offset = center - other.center
        let distance = offset.length
        let depth = radius + other.radius - distance
        guard depth > 0 else { return nil }
        return .init(
            normal: distance > 0 ? offset / distance : .init(1, 0),
            depth: depth
        )
    }

    func intersection(with ray: Ray2D) -> RayHit2D? {
        let direction = ray.normalizedDirection
        guard ray.origin.isValid, direction != .zero else { return nil }

        let offset = ray.origin - center
        let projection = offset.dot(direction)
        let discriminant = (projection * projection)
            - offset.dot(offset)
            + (radius * radius)
        guard discriminant >= 0 else { return nil }

        let root = discriminant.squareRoot()
        let near = -projection - root
        let far = -projection + root
        let distance = near >= 0 ? near : far
        guard distance >= 0 else { return nil }

        let point = ray.point(at: distance)
        return .init(normal: (point - center).normalized, distance: distance)
    }
}
