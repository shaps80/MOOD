import Swift

struct Projection2D {
    let minimum: Float
    let maximum: Float

    init(minimum: Float, maximum: Float) {
        self.minimum = minimum
        self.maximum = maximum
    }

    init(rect: Rect, axis: Vec2) {
        let center = rect.center.dot(axis)
        let halfSize = rect.size * 0.5
        let radius = (halfSize.x * abs(axis.x))
            + (halfSize.y * abs(axis.y))
        minimum = center - radius
        maximum = center + radius
    }

    init(circle: CircleColliderGeometry2D, axis: Vec2) {
        let center = circle.center.dot(axis)
        minimum = center - circle.radius
        maximum = center + circle.radius
    }

    init(capsule: CapsuleColliderGeometry2D, axis: Vec2) {
        let start = capsule.start.dot(axis)
        let end = capsule.end.dot(axis)
        minimum = Swift.min(start, end) - capsule.radius
        maximum = Swift.max(start, end) + capsule.radius
    }
}

struct SeparatingAxisContact2D {
    private var depth = Float.infinity
    private var normal = Vec2.zero

    var contact: Contact2D? {
        guard depth.isFinite else { return nil }
        return .init(normal: normal, depth: depth)
    }

    /// Tests one normalized axis and records it only when it is an exterior surface.
    mutating func include(
        axis: Vec2,
        source: Projection2D,
        target: Projection2D,
        canResolve: Bool
    ) -> Bool {
        let negativeDepth = source.maximum - target.minimum
        let positiveDepth = target.maximum - source.minimum
        guard negativeDepth > 0, positiveDepth > 0 else { return false }
        guard canResolve else { return true }

        if negativeDepth <= positiveDepth {
            if negativeDepth < depth {
                depth = negativeDepth
                normal = axis
            }
        } else if positiveDepth < depth {
            depth = positiveDepth
            normal = -axis
        }
        return true
    }
}
