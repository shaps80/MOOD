import Swift

struct CollisionResolution: Sendable {
    var normal: Vec2
    var depth: Double

    var vector: Vec2 {
        normal * depth
    }
}

extension Collider {
    func collisionResolution(against other: Collider) -> CollisionResolution? {
        let points = collisionPoints()
        let otherPoints = other.collisionPoints()

        guard points.count >= 3, otherPoints.count >= 3 else {
            return nil
        }

        return CollisionGeometry.sat(points, otherPoints)
    }

    func collisionPoints() -> [Vec2] {
        if !points.isEmpty {
            return points
        }

        return shape.collisionPoints(in: shapeFrame)
            .map { $0.rotated(around: shapeFrame.center, by: rotation) }
    }
}

extension Shape {
    func collisionPoints(in rect: Rect) -> [Vec2] {
        let path = path(in: rect)

        guard path.commands.count == 1 else {
            return rectanglePoints(in: rect)
        }

        switch path.commands[0] {
        case .addRect(let rect):
            return rectanglePoints(in: rect)

        case .addEllipse(let rect):
            return ellipsePoints(in: rect, segments: 16)

        case .addRoundedRect(let rect, let cornerRadius, _):
            return roundedRectPoints(
                in: rect,
                cornerRadius: cornerRadius,
                segmentsPerCorner: 4
            )

        default:
            return rectanglePoints(in: rect)
        }
    }
}

enum CollisionGeometry {
    static func sat(_ points: [Vec2], _ otherPoints: [Vec2]) -> CollisionResolution? {
        var smallestOverlap = Double.infinity
        var smallestAxis = Vec2.zero

        guard testAxes(
            from: points,
            points,
            otherPoints,
            smallestOverlap: &smallestOverlap,
            smallestAxis: &smallestAxis
        ),
        testAxes(
            from: otherPoints,
            points,
            otherPoints,
            smallestOverlap: &smallestOverlap,
            smallestAxis: &smallestAxis
        )
        else {
            return nil
        }

        let direction = center(of: points) - center(of: otherPoints)
        if direction.dot(smallestAxis) < 0 {
            smallestAxis = -smallestAxis
        }

        return CollisionResolution(
            normal: smallestAxis,
            depth: smallestOverlap
        )
    }

    private static func testAxes(
        from source: [Vec2],
        _ points: [Vec2],
        _ otherPoints: [Vec2],
        smallestOverlap: inout Double,
        smallestAxis: inout Vec2
    ) -> Bool {
        for index in source.indices {
            let afterIndex = source.index(after: index)
            let nextIndex = afterIndex == source.endIndex ? source.startIndex : afterIndex
            let edge = source[nextIndex] - source[index]
            guard let axis = Vec2(x: -edge.y, y: edge.x).normalized else {
                continue
            }

            let projection = project(points, onto: axis)
            let otherProjection = project(otherPoints, onto: axis)
            let overlap = min(projection.max, otherProjection.max) - max(projection.min, otherProjection.min)

            guard overlap > 0 else {
                return false
            }

            if overlap < smallestOverlap {
                smallestOverlap = overlap
                smallestAxis = axis
            }
        }

        return true
    }

    private static func project(_ points: [Vec2], onto axis: Vec2) -> (min: Double, max: Double) {
        var minValue = points[0].dot(axis)
        var maxValue = minValue

        for point in points.dropFirst() {
            let value = point.dot(axis)
            minValue = min(minValue, value)
            maxValue = max(maxValue, value)
        }

        return (minValue, maxValue)
    }

    private static func center(of points: [Vec2]) -> Vec2 {
        var total = Vec2.zero

        for point in points {
            total += point
        }

        return total * (1 / Double(points.count))
    }
}

private func rectanglePoints(in rect: Rect) -> [Vec2] {
    [
        Vec2(x: rect.minX, y: rect.minY),
        Vec2(x: rect.maxX, y: rect.minY),
        Vec2(x: rect.maxX, y: rect.maxY),
        Vec2(x: rect.minX, y: rect.maxY)
    ]
}

private func ellipsePoints(in rect: Rect, segments: Int) -> [Vec2] {
    let center = rect.center
    let radius = rect.size * 0.5

    return (0..<segments).map { index in
        let angle = Angle.radians((Double(index) / Double(segments)) * .pi * 2)
        let components = sincos(angle)
        return Vec2(
            x: center.x + (components.cos * radius.x),
            y: center.y + (components.sin * radius.y)
        )
    }
}

private func roundedRectPoints(
    in rect: Rect,
    cornerRadius: Double,
    segmentsPerCorner: Int
) -> [Vec2] {
    let radius = min(cornerRadius, min(rect.size.x, rect.size.y) / 2)
    guard radius > 0 else {
        return rectanglePoints(in: rect)
    }

    let centers = [
        Vec2(x: rect.maxX - radius, y: rect.minY + radius),
        Vec2(x: rect.maxX - radius, y: rect.maxY - radius),
        Vec2(x: rect.minX + radius, y: rect.maxY - radius),
        Vec2(x: rect.minX + radius, y: rect.minY + radius)
    ]
    let starts = [-90.0, 0.0, 90.0, 180.0]
    var points: [Vec2] = []
    points.reserveCapacity(segmentsPerCorner * 4)

    for corner in centers.indices {
        for segment in 0...segmentsPerCorner {
            let t = Double(segment) / Double(segmentsPerCorner)
            let angle = Angle.degrees(starts[corner] + (t * 90))
            let components = sincos(angle)
            points.append(
                Vec2(
                    x: centers[corner].x + (components.cos * radius),
                    y: centers[corner].y + (components.sin * radius)
                )
            )
        }
    }

    return points
}
