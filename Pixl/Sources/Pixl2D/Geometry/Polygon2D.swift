import PixlMath

/// An immutable simple polygon described by a normalized local-space boundary.
public struct Polygon2D: Equatable, Sendable, RandomAccessCollection {
    public typealias Element = Vec2
    public typealias Index = Int

    package final class Storage: @unchecked Sendable {
        package let vertices: UnsafeBufferPointer<Vec2>
        package let indices: UnsafeBufferPointer<UInt32>

        private let vertexStorage: UnsafeMutablePointer<Vec2>
        private let indexStorage: UnsafeMutablePointer<UInt32>

        init(
            vertices: ContiguousArray<Vec2>,
            indices: ContiguousArray<UInt32>
        ) {
            vertexStorage = .allocate(capacity: vertices.count)
            indexStorage = .allocate(capacity: indices.count)
            vertices.withUnsafeBufferPointer {
                vertexStorage.initialize(from: $0.baseAddress!, count: $0.count)
            }
            indices.withUnsafeBufferPointer {
                indexStorage.initialize(from: $0.baseAddress!, count: $0.count)
            }
            self.vertices = .init(start: vertexStorage, count: vertices.count)
            self.indices = .init(start: indexStorage, count: indices.count)
        }

        deinit {
            vertexStorage.deinitialize(count: vertices.count)
            vertexStorage.deallocate()
            indexStorage.deinitialize(count: indices.count)
            indexStorage.deallocate()
        }
    }

    package let storage: Storage

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
        var triangulator = PolygonTriangulator(vertices: canonicalizer.vertices)
        triangulator.triangulate()
        storage = Storage(
            vertices: canonicalizer.vertices,
            indices: triangulator.indices
        )
        bounds = canonicalizer.vertices.boundingRect
    }

    /// Creates a polygon from three or more finite boundary vertices.
    public init(_ vertices: Vec2...) {
        self.init(vertices)
    }

    public var startIndex: Int { storage.vertices.startIndex }
    public var endIndex: Int { storage.vertices.endIndex }

    public subscript(position: Int) -> Vec2 {
        storage.vertices[position]
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage.vertices.elementsEqual(rhs.storage.vertices)
    }
}

private struct PolygonTriangulator {
    let vertices: ContiguousArray<Vec2>
    var remaining: ContiguousArray<Int>
    var indices: ContiguousArray<UInt32> = []

    init(vertices: ContiguousArray<Vec2>) {
        self.vertices = vertices
        remaining = ContiguousArray(vertices.indices)
        indices.reserveCapacity((vertices.count - 2) * 3)
    }

    mutating func triangulate() {
        while remaining.count > 3 {
            var foundEar = false
            for position in remaining.indices where isEar(at: position) {
                let previous = remaining[(position + remaining.count - 1) % remaining.count]
                let current = remaining[position]
                let next = remaining[(position + 1) % remaining.count]
                indices.append(UInt32(previous))
                indices.append(UInt32(current))
                indices.append(UInt32(next))
                remaining.remove(at: position)
                foundEar = true
                break
            }
            precondition(foundEar, "Polygon2D could not triangulate its boundary")
        }
        indices.append(UInt32(remaining[0]))
        indices.append(UInt32(remaining[1]))
        indices.append(UInt32(remaining[2]))
    }

    private func isEar(at position: Int) -> Bool {
        let previousIndex = remaining[(position + remaining.count - 1) % remaining.count]
        let currentIndex = remaining[position]
        let nextIndex = remaining[(position + 1) % remaining.count]
        let a = vertices[previousIndex]
        let b = vertices[currentIndex]
        let c = vertices[nextIndex]
        guard PixlMath.cross(b - a, c - b) > 0 else { return false }

        for candidateIndex in remaining
        where candidateIndex != previousIndex
            && candidateIndex != currentIndex
            && candidateIndex != nextIndex
        {
            if contains(vertices[candidateIndex], a: a, b: b, c: c) {
                return false
            }
        }
        return true
    }

    private func contains(_ point: Vec2, a: Vec2, b: Vec2, c: Vec2) -> Bool {
        PixlMath.cross(b - a, point - a) >= 0
            && PixlMath.cross(c - b, point - b) >= 0
            && PixlMath.cross(a - c, point - c) >= 0
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
