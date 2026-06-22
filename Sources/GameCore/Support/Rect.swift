import Swift

public struct Rect: Equatable, Sendable {
    public var origin: Vec2
    public var size: Vec2

    public init(origin: Vec2, size: Vec2) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(
            origin: Vec2(x: x, y: y),
            size: Vec2(x: width, y: height)
        )
    }

    public static let zero: Self = .init(
        origin: .zero,
        size: .zero
    )
}

public extension Rect {
    var minX: Double {
        origin.x
    }

    var maxX: Double {
        origin.x + size.x
    }

    var minY: Double {
        origin.y
    }

    var maxY: Double {
        origin.y + size.y
    }

    func translated(by offset: Vec2) -> Rect {
        Rect(
            origin: Vec2(
                x: origin.x + offset.x,
                y: origin.y + offset.y
            ),
            size: size
        )
    }

    func padding(_ edges: Edge.Set = .all, _ amount: Double) -> Rect {
        var origin = origin
        var size = size

        if edges.contains(.left) {
            origin = Vec2(x: origin.x + amount, y: origin.y)
            size = Vec2(x: size.x - amount, y: size.y)
        }

        if edges.contains(.right) {
            size = Vec2(x: size.x - amount, y: size.y)
        }

        if edges.contains(.top) {
            origin = Vec2(x: origin.x, y: origin.y + amount)
            size = Vec2(x: size.x, y: size.y - amount)
        }

        if edges.contains(.bottom) {
            size = Vec2(x: size.x, y: size.y - amount)
        }

        return Rect(origin: origin, size: size)
    }

    func intersects(_ other: Rect) -> Bool {
        minX < other.maxX
            && maxX > other.minX
            && minY < other.maxY
            && maxY > other.minY
    }
}
