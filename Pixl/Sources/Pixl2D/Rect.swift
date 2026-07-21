import Swift

/// An axis-aligned rectangle described by an origin and size.
///
/// `Rect` is used for bounds, viewports, collision boxes, and camera regions in
/// Pixl's platform-neutral model.
///
/// ```swift
/// let bounds = Rect(x: 0, y: 0, width: 320, height: 180)
/// let padded = bounds.padding(8)
/// ```
public struct Rect: Equatable, Sendable {
    /// The minimum x/y corner of the rectangle.
    ///
    /// ```swift
    /// let rect = Rect(x: 10, y: 20, width: 30, height: 40)
    /// let origin = rect.origin
    /// ```
    public var origin: Vec2

    /// The width and height of the rectangle.
    ///
    /// ```swift
    /// let rect = Rect(x: 10, y: 20, width: 30, height: 40)
    /// let size = rect.size
    /// ```
    public var size: Vec2

    /// Creates a rectangle from origin and size vectors.
    ///
    /// ```swift
    /// let rect = Rect(origin: Vec2.zero, size: Vec2(x: 320, y: 180))
    /// ```
    /// - Parameters:
    ///   - origin: Minimum x/y corner.
    ///   - size: Width and height.
    public init(origin: Vec2, size: Vec2) {
        self.origin = origin
        self.size = size
    }

    /// Creates a rectangle from scalar position and size values.
    ///
    /// ```swift
    /// let rect = Rect(x: 0, y: 0, width: 320, height: 180)
    /// ```
    /// - Parameters:
    ///   - x: Minimum x coordinate.
    ///   - y: Minimum y coordinate.
    ///   - width: Rectangle width.
    ///   - height: Rectangle height.
    public init(x: Float, y: Float, width: Float, height: Float) {
        self.init(
            origin: Vec2(x: x, y: y),
            size: Vec2(x: width, y: height)
        )
    }

    /// Creates a rectangle centred on a point.
    ///
    /// - Parameters:
    ///   - center: Point placed at the rectangle's centre.
    ///   - size: Rectangle width and height.
    public init(center: Vec2, size: Vec2) {
        self.init(
            origin: Vec2(
                x: center.x - (size.x / 2),
                y: center.y - (size.y / 2)
            ),
            size: size
        )
    }

    /// Creates a rectangle of the given size at the origin.
    /// - Parameter size: Rectangle width and height.
    public init(size: Vec2) {
        self.init(origin: .zero, size: size)
    }

    /// A rectangle with zero origin and zero size.
    ///
    /// ```swift
    /// let empty = Rect.zero
    /// ```
    public static let zero: Self = .init(
        origin: .zero,
        size: .zero
    )
}

public extension Rect {
    /// The minimum x coordinate.
    ///
    /// ```swift
    /// let left = Rect(x: 10, y: 20, width: 30, height: 40).minX
    /// ```
    var minX: Float {
        origin.x
    }

    /// The maximum x coordinate.
    ///
    /// ```swift
    /// let right = Rect(x: 10, y: 20, width: 30, height: 40).maxX
    /// ```
    var maxX: Float {
        origin.x + size.x
    }

    /// The minimum y coordinate.
    ///
    /// ```swift
    /// let top = Rect(x: 10, y: 20, width: 30, height: 40).minY
    /// ```
    var minY: Float {
        origin.y
    }

    /// The maximum y coordinate.
    ///
    /// ```swift
    /// let bottom = Rect(x: 10, y: 20, width: 30, height: 40).maxY
    /// ```
    var maxY: Float {
        origin.y + size.y
    }

    /// The center point of the rectangle.
    ///
    /// ```swift
    /// let center = Rect(x: 0, y: 0, width: 10, height: 20).center
    /// ```
    var center: Vec2 {
        Vec2(
            x: origin.x + (size.x / 2),
            y: origin.y + (size.y / 2)
        )
    }

    /// Returns a copy offset by the supplied vector.
    ///
    /// ```swift
    /// let moved = Rect(x: 0, y: 0, width: 10, height: 10)
    ///     .translated(by: Vec2(x: 5, y: 2))
    /// ```
    /// - Parameter offset: Component-wise displacement.
    /// - Returns: A copy with `origin` displaced by `offset`.
    func translated(by offset: Vec2) -> Rect {
        Rect(
            origin: Vec2(
                x: origin.x + offset.x,
                y: origin.y + offset.y
            ),
            size: size
        )
    }

    /// Returns a rectangle with its origin and size scaled component-wise.
    /// - Parameter scale: Independent x and y scale factors.
    /// - Returns: The scaled rectangle.
    func scaled(by scale: Vec2) -> Rect {
        Rect(
            origin: origin * scale,
            size: size * scale
        )
    }

    /// Returns a rectangle inset on every edge by the same amount.
    ///
    /// ```swift
    /// let inner = Rect(x: 0, y: 0, width: 100, height: 100).padding(8)
    /// ```
    /// - Parameter amount: Distance to move each edge inward. Negative values expand the rectangle.
    /// - Returns: The inset rectangle.
    func padding(_ amount: Float) -> Rect {
        padding(.all, amount)
    }

    /// Returns a rectangle inset on the selected edges.
    ///
    /// ```swift
    /// let inner = Rect(x: 0, y: 0, width: 100, height: 100)
    ///     .padding(.horizontal, 12)
    /// ```
    /// - Parameters:
    ///   - edges: Edges to move inward.
    ///   - amount: Distance to move each selected edge. Negative values expand the rectangle.
    /// - Returns: The selectively inset rectangle.
    func padding(_ edges: Edge.Set = .all, _ amount: Float) -> Rect {
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

    /// Returns whether this rectangle overlaps another rectangle.
    ///
    /// Touching edges without overlap return `false`.
    ///
    /// ```swift
    /// let player = Rect(x: 0, y: 0, width: 16, height: 16)
    /// let pickup = Rect(x: 8, y: 8, width: 8, height: 8)
    /// let overlaps = player.intersects(pickup)
    /// ```
    /// - Parameter other: Rectangle to test against this rectangle.
    /// - Returns: `true` when the rectangles overlap with positive area.
    func intersects(_ other: Rect) -> Bool {
        minX < other.maxX
            && maxX > other.minX
            && minY < other.maxY
            && maxY > other.minY
    }
}

public extension Rect {
    /// A copy whose edges are rounded to integral coordinates.
    var integral: Rect {
        let minX = origin.x.rounded()
        let minY = origin.y.rounded()
        let maxX = (origin.x + size.x).rounded()
        let maxY = (origin.y + size.y).rounded()

        return Rect(
            x: minX,
            y: minY,
            width: max(0, maxX - minX),
            height: max(0, maxY - minY)
        )
    }
}

public extension Rect {
    /// Returns the smallest axis-aligned rectangle containing both rectangles.
    /// - Parameter other: Rectangle to include with this rectangle.
    /// - Returns: The bounding union of both rectangles.
    func union(_ other: Rect) -> Rect {
        let minX = min(minX, other.minX)
        let minY = min(minY, other.minY)
        let maxX = max(maxX, other.maxX)
        let maxY = max(maxY, other.maxY)

        return Rect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
}
