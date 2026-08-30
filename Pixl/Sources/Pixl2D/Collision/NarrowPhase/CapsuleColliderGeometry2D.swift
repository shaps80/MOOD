import Swift

/// Collision-ready world-space lowering of one immutable local-space capsule.
final class CapsuleColliderGeometry2D {
    let geometry: Capsule2D

    private(set) var segment: Segment
    private(set) var radius: Float = 0
    private(set) var bounds = Rect.invalid
    private(set) var tangent = Vec2.zero
    private(set) var normal = Vec2.zero
    private(set) var length: Float = 0
    private var pendingTransform: Transform2D

    var start: Vec2 { segment.start }
    var end: Vec2 { segment.end }

    init(_ capsule: Capsule2D, transform: Transform2D) {
        geometry = capsule
        segment = capsule.segment
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
        segment = Segment(
            start: pendingTransform.transformed(point: geometry.segment.start),
            end: pendingTransform.transformed(point: geometry.segment.end)
        )
        radius = geometry.radius * scale
        let direction = end - start
        length = direction.length
        tangent = direction / length
        normal = .init(-tangent.y, tangent.x)

        let minimum = Vec2(
            Swift.min(start.x, end.x) - radius,
            Swift.min(start.y, end.y) - radius
        )
        let maximum = Vec2(
            Swift.max(start.x, end.x) + radius,
            Swift.max(start.y, end.y) + radius
        )
        bounds = Rect(origin: minimum, size: maximum - minimum)
    }

    /// Returns a contact directed from `rect` toward this capsule.
    func contact(from rect: Rect) -> Contact2D? {
        var test = SeparatingAxisContact2D()
        let horizontal = Vec2(1, 0)
        let vertical = Vec2(0, 1)
        guard includeAxis(
            horizontal,
            source: rect,
            test: &test
        ), includeAxis(
            vertical,
            source: rect,
            test: &test
        ), includeAxis(
            normal,
            source: rect,
            test: &test
        ), includeAxis(
            tangent,
            source: rect,
            test: &test
        ), includeVertex(
            rect.origin,
            source: rect,
            test: &test
        ), includeVertex(
            .init(rect.maxX, rect.minY),
            source: rect,
            test: &test
        ), includeVertex(
            .init(rect.minX, rect.maxY),
            source: rect,
            test: &test
        ), includeVertex(
            .init(rect.maxX, rect.maxY),
            source: rect,
            test: &test
        ) else { return nil }
        return test.contact
    }

    /// Returns a contact directed from `circle` toward this capsule.
    func contact(from circle: CircleColliderGeometry2D) -> Contact2D? {
        let closest = segment.closestPoint(to: circle.center)
        let distance = (circle.center - closest).length
        guard distance < radius + circle.radius else { return nil }

        var test = SeparatingAxisContact2D()
        guard includeAxis(normal, source: circle, test: &test),
              includeAxis(tangent, source: circle, test: &test)
        else { return nil }
        let closestAxis = (closest - circle.center).normalized
        if closestAxis != .zero,
           !includeAxis(closestAxis, source: circle, test: &test) {
            return nil
        }
        return test.contact
    }

    /// Returns a contact directed from `other` toward this capsule.
    func contact(from other: CapsuleColliderGeometry2D) -> Contact2D? {
        let closest = other.segment.closestPoints(to: segment)
        let distance = (closest.second - closest.first).length
        guard distance < radius + other.radius else { return nil }

        var test = SeparatingAxisContact2D()
        guard includeAxis(normal, source: other, test: &test),
              includeAxis(tangent, source: other, test: &test),
              includeAxis(other.normal, source: other, test: &test),
              includeAxis(other.tangent, source: other, test: &test)
        else { return nil }

        let closestAxis = (closest.second - closest.first).normalized
        if closestAxis != .zero,
           !includeAxis(closestAxis, source: other, test: &test) {
            return nil
        }
        return test.contact
    }

    func intersection(with ray: Ray2D) -> RayHit2D? {
        let direction = ray.normalizedDirection
        guard ray.origin.isValid, direction != .zero else { return nil }

        var nearestDistance = Float.infinity
        var nearestNormal = Vec2.zero
        let originOffset = ray.origin - start
        let directionAcross = direction.dot(normal)

        if directionAcross != 0 {
            includeSideIntersection(
                distance: (radius - originOffset.dot(normal)) / directionAcross,
                sideNormal: normal,
                ray: ray,
                nearestDistance: &nearestDistance,
                nearestNormal: &nearestNormal
            )
            includeSideIntersection(
                distance: (-radius - originOffset.dot(normal)) / directionAcross,
                sideNormal: -normal,
                ray: ray,
                nearestDistance: &nearestDistance,
                nearestNormal: &nearestNormal
            )
        }

        includeCapIntersections(
            center: start,
            isStart: true,
            ray: ray,
            nearestDistance: &nearestDistance,
            nearestNormal: &nearestNormal
        )
        includeCapIntersections(
            center: end,
            isStart: false,
            ray: ray,
            nearestDistance: &nearestDistance,
            nearestNormal: &nearestNormal
        )

        guard nearestDistance.isFinite else { return nil }
        return .init(normal: nearestNormal, distance: nearestDistance)
    }

    @inline(__always)
    private func includeAxis(
        _ axis: Vec2,
        source rect: Rect,
        test: inout SeparatingAxisContact2D
    ) -> Bool {
        let axis = axis.normalized
        guard axis != .zero else { return true }
        return test.include(
            axis: axis,
            source: .init(rect: rect, axis: axis),
            target: .init(capsule: self, axis: axis),
            canResolve: true
        )
    }

    @inline(__always)
    private func includeVertex(
        _ vertex: Vec2,
        source rect: Rect,
        test: inout SeparatingAxisContact2D
    ) -> Bool {
        includeAxis(
            vertex - segment.closestPoint(to: vertex),
            source: rect,
            test: &test
        )
    }

    @inline(__always)
    private func includeAxis(
        _ axis: Vec2,
        source circle: CircleColliderGeometry2D,
        test: inout SeparatingAxisContact2D
    ) -> Bool {
        let axis = axis.normalized
        guard axis != .zero else { return true }
        return test.include(
            axis: axis,
            source: .init(circle: circle, axis: axis),
            target: .init(capsule: self, axis: axis),
            canResolve: true
        )
    }

    @inline(__always)
    private func includeAxis(
        _ axis: Vec2,
        source other: CapsuleColliderGeometry2D,
        test: inout SeparatingAxisContact2D
    ) -> Bool {
        let axis = axis.normalized
        guard axis != .zero else { return true }
        return test.include(
            axis: axis,
            source: .init(capsule: other, axis: axis),
            target: .init(capsule: self, axis: axis),
            canResolve: true
        )
    }

    private func includeSideIntersection(
        distance: Float,
        sideNormal: Vec2,
        ray: Ray2D,
        nearestDistance: inout Float,
        nearestNormal: inout Vec2
    ) {
        guard distance >= 0, distance < nearestDistance else { return }
        let position = (ray.point(at: distance) - start).dot(tangent)
        guard position >= 0, position <= length else { return }
        nearestDistance = distance
        nearestNormal = sideNormal
    }

    private func includeCapIntersections(
        center: Vec2,
        isStart: Bool,
        ray: Ray2D,
        nearestDistance: inout Float,
        nearestNormal: inout Vec2
    ) {
        let offset = ray.origin - center
        let projection = offset.dot(ray.normalizedDirection)
        let discriminant = (projection * projection)
            - offset.dot(offset)
            + (radius * radius)
        guard discriminant >= 0 else { return }

        let root = discriminant.squareRoot()
        let near = -projection - root
        let far = -projection + root
        includeCapIntersection(
            distance: near,
            center: center,
            isStart: isStart,
            ray: ray,
            nearestDistance: &nearestDistance,
            nearestNormal: &nearestNormal
        )
        includeCapIntersection(
            distance: far,
            center: center,
            isStart: isStart,
            ray: ray,
            nearestDistance: &nearestDistance,
            nearestNormal: &nearestNormal
        )
    }

    private func includeCapIntersection(
        distance: Float,
        center: Vec2,
        isStart: Bool,
        ray: Ray2D,
        nearestDistance: inout Float,
        nearestNormal: inout Vec2
    ) {
        guard distance >= 0, distance < nearestDistance else { return }
        let point = ray.point(at: distance)
        let axialPosition = (point - start).dot(tangent)
        guard isStart ? axialPosition <= 0 : axialPosition >= length else {
            return
        }
        nearestDistance = distance
        nearestNormal = (point - center).normalized
    }
}
