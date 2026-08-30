import PixlMath
import Swift

/// Collision-ready world-space lowering of one immutable polygon.
final class PolygonColliderGeometry2D {
    let storage: Polygon2D.Storage
    let vertices: UnsafeMutablePointer<Vec2>
    let vertexCount: Int
    private let triangleAxes: UnsafeMutablePointer<Vec2>
    private let boundaryEdges: UnsafeMutablePointer<Bool>
    private let triangleValueCount: Int

    private(set) var bounds: Rect
    private var winding: Float = 1
    private var pendingTransform: Transform2D

    init(_ polygon: Polygon2D, transform: Transform2D) {
        storage = polygon.storage
        vertexCount = storage.vertices.count
        triangleValueCount = storage.indices.count
        vertices = .allocate(capacity: vertexCount)
        vertices.initialize(repeating: .zero, count: vertexCount)
        triangleAxes = .allocate(capacity: triangleValueCount)
        triangleAxes.initialize(repeating: .zero, count: triangleValueCount)
        boundaryEdges = .allocate(capacity: triangleValueCount)
        for triangle in stride(from: 0, to: triangleValueCount, by: 3) {
            for edge in 0..<3 {
                let start = Int(storage.indices[triangle + edge])
                let end = Int(storage.indices[triangle + ((edge + 1) % 3)])
                boundaryEdges.advanced(by: triangle + edge).initialize(
                    to: (start + 1) % vertexCount == end
                        || (end + 1) % vertexCount == start
                )
            }
        }
        bounds = .invalid
        pendingTransform = transform
        synchronize()
    }

    deinit {
        vertices.deinitialize(count: vertexCount)
        vertices.deallocate()
        triangleAxes.deinitialize(count: triangleValueCount)
        triangleAxes.deallocate()
        boundaryEdges.deinitialize(count: triangleValueCount)
        boundaryEdges.deallocate()
    }

    /// Stores the latest transform without rebuilding collision geometry.
    @discardableResult
    func setTransform(_ transform: Transform2D) -> Bool {
        guard pendingTransform.x != transform.x
            || pendingTransform.y != transform.y
            || pendingTransform.translation != transform.translation
        else { return false }
        pendingTransform = transform
        return true
    }

    /// Rebuilds transformed vertices and exact broad-phase bounds once.
    func synchronize() {
        let transform = pendingTransform
        var minimum = Vec2(repeating: .infinity)
        var maximum = Vec2(repeating: -.infinity)

        for index in 0..<vertexCount {
            let local = storage.vertices[index]
            let vertex = Vec2(
                (transform.x.x * local.x)
                    + (transform.y.x * local.y)
                    + transform.translation.x,
                (transform.x.y * local.x)
                    + (transform.y.y * local.y)
                    + transform.translation.y
            )
            vertices[index] = vertex
            minimum = Vec2(
                Swift.min(minimum.x, vertex.x),
                Swift.min(minimum.y, vertex.y)
            )
            maximum = Vec2(
                Swift.max(maximum.x, vertex.x),
                Swift.max(maximum.y, vertex.y)
            )
        }

        for triangle in stride(from: 0, to: triangleValueCount, by: 3) {
            for edge in 0..<3 {
                let start = Int(storage.indices[triangle + edge])
                let end = Int(storage.indices[triangle + ((edge + 1) % 3)])
                let value = vertices[end] - vertices[start]
                triangleAxes[triangle + edge] = Vec2(
                    value.y,
                    -value.x
                ).normalized
            }
        }

        let determinant = (transform.x.x * transform.y.y)
            - (transform.x.y * transform.y.x)
        winding = determinant < 0 ? -1 : 1
        bounds = Rect(origin: minimum, size: maximum - minimum)
    }

    /// Returns a contact directed from `rect` toward this polygon.
    func contact(from rect: Rect) -> Contact2D? {
        var best: Contact2D?
        let indices = storage.indices

        for triangle in stride(from: 0, to: indices.count, by: 3) {
            let a = Int(indices[triangle])
            let b = Int(indices[triangle + 1])
            let c = Int(indices[triangle + 2])
            guard let contact = contact(
                from: rect,
                triangle: (a, b, c),
                axisOffset: triangle
            ) else { continue }
            if best == nil || contact.depth < best!.depth {
                best = contact
            }
        }

        return best
    }

    /// Returns a contact directed from `other` toward this polygon.
    func contact(from other: PolygonColliderGeometry2D) -> Contact2D? {
        var best: Contact2D?
        let sourceIndices = other.storage.indices
        let targetIndices = storage.indices

        for sourceTriangle in stride(
            from: 0,
            to: sourceIndices.count,
            by: 3
        ) {
            let source = (
                Int(sourceIndices[sourceTriangle]),
                Int(sourceIndices[sourceTriangle + 1]),
                Int(sourceIndices[sourceTriangle + 2])
            )
            for targetTriangle in stride(
                from: 0,
                to: targetIndices.count,
                by: 3
            ) {
                let target = (
                    Int(targetIndices[targetTriangle]),
                    Int(targetIndices[targetTriangle + 1]),
                    Int(targetIndices[targetTriangle + 2])
                )
                guard let contact = contact(
                    from: other,
                    sourceTriangle: source,
                    sourceAxisOffset: sourceTriangle,
                    targetTriangle: target,
                    targetAxisOffset: targetTriangle
                ) else { continue }
                if best == nil || contact.depth < best!.depth {
                    best = contact
                }
            }
        }

        return best
    }

    /// Returns a contact directed from `circle` toward this polygon.
    func contact(from circle: CircleColliderGeometry2D) -> Contact2D? {
        var nearestDistanceSquared = Float.infinity
        var nearestPoint = Vec2.zero
        var nearestOutwardNormal = Vec2.zero

        for index in 0..<vertexCount {
            let start = vertices[index]
            let end = vertices[(index + 1) % vertexCount]
            let edge = Segment(start: start, end: end)
            let point = edge.closestPoint(to: circle.center)
            let offset = point - circle.center
            let distanceSquared = offset.dot(offset)
            if distanceSquared < nearestDistanceSquared {
                nearestDistanceSquared = distanceSquared
                nearestPoint = point
                let direction = end - start
                nearestOutwardNormal = Vec2(
                    direction.y,
                    -direction.x
                ).normalized * winding
            }
        }

        let distance = nearestDistanceSquared.squareRoot()
        if contains(circle.center) {
            let outward = distance > 0
                ? (nearestPoint - circle.center) / distance
                : nearestOutwardNormal
            return .init(
                normal: -outward,
                depth: circle.radius + distance
            )
        }

        let depth = circle.radius - distance
        guard depth > 0 else { return nil }
        let normal = distance > 0
            ? (nearestPoint - circle.center) / distance
            : -nearestOutwardNormal
        return .init(normal: normal, depth: depth)
    }

    /// Returns a contact directed from `capsule` toward this polygon.
    func contact(from capsule: CapsuleColliderGeometry2D) -> Contact2D? {
        var best: Contact2D?
        let indices = storage.indices

        for triangle in stride(from: 0, to: indices.count, by: 3) {
            let vertices = (
                Int(indices[triangle]),
                Int(indices[triangle + 1]),
                Int(indices[triangle + 2])
            )
            guard let contact = contact(
                from: capsule,
                triangle: vertices,
                axisOffset: triangle
            ) else { continue }
            if best == nil || contact.depth < best!.depth {
                best = contact
            }
        }
        return best
    }

    /// Returns the nearest intersection with the original polygon boundary.
    func intersection(with ray: Ray2D) -> RayHit2D? {
        let direction = ray.normalizedDirection
        guard ray.origin.isValid, direction != .zero else { return nil }

        var nearestDistance = Float.infinity
        var nearestNormal = Vec2.zero

        for index in 0..<vertexCount {
            let start = vertices[index]
            let end = vertices[(index + 1) % vertexCount]
            let edge = end - start
            let denominator = PixlMath.cross(direction, edge)
            guard denominator != 0 else { continue }

            let offset = start - ray.origin
            let distance = PixlMath.cross(offset, edge) / denominator
            let edgePosition = PixlMath.cross(offset, direction) / denominator
            guard distance >= 0,
                  edgePosition >= 0,
                  edgePosition <= 1,
                  distance < nearestDistance
            else { continue }

            nearestDistance = distance
            nearestNormal = Vec2(edge.y, -edge.x).normalized * winding
        }

        guard nearestDistance.isFinite else { return nil }
        return RayHit2D(normal: nearestNormal, distance: nearestDistance)
    }

    private func contact(
        from rect: Rect,
        triangle: (Int, Int, Int),
        axisOffset: Int
    ) -> Contact2D? {
        var test = SeparatingAxisContact2D()

        guard test.include(
            axis: .init(1, 0),
            source: .init(rect: rect, axis: .init(1, 0)),
            target: projection(of: triangle, axis: .init(1, 0)),
            canResolve: true
        ), test.include(
            axis: .init(0, 1),
            source: .init(rect: rect, axis: .init(0, 1)),
            target: projection(of: triangle, axis: .init(0, 1)),
            canResolve: true
        ) else { return nil }

        for edgeIndex in 0..<3 {
            let axis = triangleAxes[axisOffset + edgeIndex]
            guard axis != .zero else { continue }
            guard test.include(
                axis: axis,
                source: .init(rect: rect, axis: axis),
                target: projection(of: triangle, axis: axis),
                canResolve: boundaryEdges[axisOffset + edgeIndex]
            ) else { return nil }
        }

        return test.contact
    }

    private func contact(
        from other: PolygonColliderGeometry2D,
        sourceTriangle: (Int, Int, Int),
        sourceAxisOffset: Int,
        targetTriangle: (Int, Int, Int),
        targetAxisOffset: Int
    ) -> Contact2D? {
        var test = SeparatingAxisContact2D()

        for edgeIndex in 0..<3 {
            let axis = other.triangleAxes[sourceAxisOffset + edgeIndex]
            guard axis != .zero else { continue }
            guard test.include(
                axis: axis,
                source: other.projection(of: sourceTriangle, axis: axis),
                target: projection(of: targetTriangle, axis: axis),
                canResolve: other.boundaryEdges[sourceAxisOffset + edgeIndex]
            ) else { return nil }
        }

        for edgeIndex in 0..<3 {
            let axis = triangleAxes[targetAxisOffset + edgeIndex]
            guard axis != .zero else { continue }
            guard test.include(
                axis: axis,
                source: other.projection(of: sourceTriangle, axis: axis),
                target: projection(of: targetTriangle, axis: axis),
                canResolve: boundaryEdges[targetAxisOffset + edgeIndex]
            ) else { return nil }
        }

        return test.contact
    }

    private func contact(
        from capsule: CapsuleColliderGeometry2D,
        triangle: (Int, Int, Int),
        axisOffset: Int
    ) -> Contact2D? {
        var test = SeparatingAxisContact2D()

        for edgeIndex in 0..<3 {
            let axis = triangleAxes[axisOffset + edgeIndex]
            guard axis != .zero else { continue }
            guard test.include(
                axis: axis,
                source: .init(capsule: capsule, axis: axis),
                target: projection(of: triangle, axis: axis),
                canResolve: boundaryEdges[axisOffset + edgeIndex]
            ) else { return nil }
        }

        guard include(
            capsule.normal,
            capsule: capsule,
            triangle: triangle,
            test: &test
        ), include(
            capsule.tangent,
            capsule: capsule,
            triangle: triangle,
            test: &test
        ), include(
            vertex: vertices[triangle.0],
            capsule: capsule,
            triangle: triangle,
            test: &test
        ), include(
            vertex: vertices[triangle.1],
            capsule: capsule,
            triangle: triangle,
            test: &test
        ), include(
            vertex: vertices[triangle.2],
            capsule: capsule,
            triangle: triangle,
            test: &test
        ) else { return nil }

        return test.contact
    }

    @inline(__always)
    private func include(
        _ axis: Vec2,
        capsule: CapsuleColliderGeometry2D,
        triangle: (Int, Int, Int),
        test: inout SeparatingAxisContact2D
    ) -> Bool {
        let axis = axis.normalized
        guard axis != .zero else { return true }
        return test.include(
            axis: axis,
            source: .init(capsule: capsule, axis: axis),
            target: projection(of: triangle, axis: axis),
            canResolve: true
        )
    }

    @inline(__always)
    private func include(
        vertex: Vec2,
        capsule: CapsuleColliderGeometry2D,
        triangle: (Int, Int, Int),
        test: inout SeparatingAxisContact2D
    ) -> Bool {
        include(
            vertex - capsule.segment.closestPoint(to: vertex),
            capsule: capsule,
            triangle: triangle,
            test: &test
        )
    }

    private func contains(_ point: Vec2) -> Bool {
        var inside = false
        var previous = vertices[vertexCount - 1]
        for index in 0..<vertexCount {
            let current = vertices[index]
            if (current.y > point.y) != (previous.y > point.y),
               point.x < (previous.x - current.x)
                    * (point.y - current.y)
                    / (previous.y - current.y)
                    + current.x {
                inside.toggle()
            }
            previous = current
        }
        return inside
    }

    @inline(__always)
    private func projection(
        of triangle: (Int, Int, Int),
        axis: Vec2
    ) -> Projection2D {
        let first = vertices[triangle.0].dot(axis)
        let second = vertices[triangle.1].dot(axis)
        let third = vertices[triangle.2].dot(axis)
        return .init(
            minimum: min(first, min(second, third)),
            maximum: max(first, max(second, third))
        )
    }

}
