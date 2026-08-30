import PixlMath

/// An immutable simple polygon described by a normalized local-space boundary.
public struct Polygon2D: Equatable, Sendable, RandomAccessCollection {
    public typealias Element = Vec2
    public typealias Index = Int

    private let storage: ContiguousArray<Vec2>

    /// Axis-aligned local-space bounds enclosing every vertex.
    public let bounds: Rect

    /// Creates a polygon from three or more finite boundary vertices.
    ///
    /// A repeated closing vertex, consecutive duplicates, and redundant
    /// collinear vertices are removed. Clockwise input is normalized to
    /// counter-clockwise winding. Invalid or self-intersecting input is a
    /// programmer error.
    public init<Vertices: Collection>(_ vertices: Vertices)
    where Vertices.Element == Vec2 {
        var canonicalizer = PolygonCanonicalizer(vertices)
        canonicalizer.canonicalize()
        storage = canonicalizer.vertices
        bounds = canonicalizer.vertices.boundingRect
    }

    /// Creates a polygon from three or more finite boundary vertices.
    public init(_ vertices: Vec2...) {
        self.init(vertices)
    }

    public var startIndex: Int { storage.startIndex }
    public var endIndex: Int { storage.endIndex }

    public subscript(position: Int) -> Vec2 {
        storage[position]
    }
}

private struct PolygonCanonicalizer {
    var vertices: ContiguousArray<Vec2>

    init<Vertices: Collection>(_ source: Vertices)
    where Vertices.Element == Vec2 {
        vertices = []
        vertices.reserveCapacity(source.count)
        for vertex in source {
            precondition(
                vertex.x.isFinite && vertex.y.isFinite,
                "Polygon2D vertices must be finite"
            )
            if vertices.last != vertex {
                vertices.append(vertex)
            }
        }
    }

    mutating func canonicalize() {
        if vertices.count > 1, vertices.first == vertices.last {
            vertices.removeLast()
        }

        removeCollinearVertices()
        precondition(
            vertices.count >= 3,
            "Polygon2D requires at least three distinct non-collinear vertices"
        )
        precondition(
            !hasSelfIntersection,
            "Polygon2D edges must not self-intersect"
        )

        let twiceArea = signedTwiceArea
        precondition(twiceArea != 0, "Polygon2D must enclose nonzero area")
        if twiceArea < 0 {
            vertices.reverse()
        }
    }

    mutating func removeCollinearVertices() {
        guard vertices.count >= 3 else { return }
        var index = 0
        while vertices.count >= 3, index < vertices.count {
            let previous = vertices[(index + vertices.count - 1) % vertices.count]
            let current = vertices[index]
            let next = vertices[(index + 1) % vertices.count]
            if PixlMath.cross(current - previous, next - current) == 0 {
                vertices.remove(at: index)
                if index == vertices.count { index = 0 }
            } else {
                index += 1
            }
        }
    }

    var signedTwiceArea: Float {
        var area: Float = 0
        for index in vertices.indices {
            let next = vertices[(index + 1) % vertices.count]
            area += PixlMath.cross(vertices[index], next)
        }
        return area
    }

    var hasSelfIntersection: Bool {
        let count = vertices.count
        guard count >= 4 else { return false }
        for first in 0..<count {
            let firstNext = (first + 1) % count
            for second in (first + 1)..<count {
                let secondNext = (second + 1) % count
                if first == secondNext || firstNext == second { continue }
                let firstSegment = Segment(
                    start: vertices[first],
                    end: vertices[firstNext]
                )
                let secondSegment = Segment(
                    start: vertices[second],
                    end: vertices[secondNext]
                )
                if firstSegment.intersects(secondSegment) {
                    return true
                }
            }
        }
        return false
    }
}
