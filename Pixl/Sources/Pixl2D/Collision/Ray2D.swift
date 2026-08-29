import Swift

public struct Ray2D: Sendable, Equatable {
    public let origin: Vec2
    public let normalizedDirection: Vec2

    public init(origin: Vec2, direction: Vec2) {
        self.origin = origin
        self.normalizedDirection = direction.normalized
    }

    public func point(at distance: Float) -> Vec2 {
        origin + normalizedDirection * distance
    }
}

public struct RayHit2D: Sendable, Equatable {
    public let normal: Vec2
    public let distance: Float

    public init(normal: Vec2, distance: Float) {
        self.normal = normal
        self.distance = distance
    }
}

public extension Rect {
    func intersection(with ray: Ray2D) -> RayHit2D? {
        let direction = ray.normalizedDirection

        guard ray.origin.isValid,
              direction != .zero
        else {
            return nil
        }

        var entryDistance = -Float.infinity
        var exitDistance = Float.infinity
        var entryNormal = Vec2.zero
        var exitNormal = Vec2.zero

        if direction.x == 0 {
            guard ray.origin.x >= minX, ray.origin.x <= maxX else {
                return nil
            }
        } else {
            let inverseDirection = 1 / direction.x
            var nearDistance = (minX - ray.origin.x) * inverseDirection
            var farDistance = (maxX - ray.origin.x) * inverseDirection
            var nearNormal = Vec2(-1, 0)
            var farNormal = Vec2(1, 0)

            if nearDistance > farDistance {
                swap(&nearDistance, &farDistance)
                swap(&nearNormal, &farNormal)
            }

            entryDistance = nearDistance
            exitDistance = farDistance
            entryNormal = nearNormal
            exitNormal = farNormal
        }

        if direction.y == 0 {
            guard ray.origin.y >= minY, ray.origin.y <= maxY else {
                return nil
            }
        } else {
            let inverseDirection = 1 / direction.y
            var nearDistance = (minY - ray.origin.y) * inverseDirection
            var farDistance = (maxY - ray.origin.y) * inverseDirection
            var nearNormal = Vec2(0, -1)
            var farNormal = Vec2(0, 1)

            if nearDistance > farDistance {
                swap(&nearDistance, &farDistance)
                swap(&nearNormal, &farNormal)
            }

            if nearDistance > entryDistance {
                entryDistance = nearDistance
                entryNormal = nearNormal
            }

            if farDistance < exitDistance {
                exitDistance = farDistance
                exitNormal = farNormal
            }
        }

        guard entryDistance <= exitDistance, exitDistance >= 0 else {
            return nil
        }

        if entryDistance >= 0 {
            return RayHit2D(normal: entryNormal, distance: entryDistance)
        }

        return RayHit2D(normal: exitNormal, distance: exitDistance)
    }
}
