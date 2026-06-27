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
    public init(origin: Vec2, size: Vec2) {
        self.origin = origin
        self.size = size
    }

    /// Creates a rectangle from scalar position and size values.
    ///
    /// ```swift
    /// let rect = Rect(x: 0, y: 0, width: 320, height: 180)
    /// ```
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(
            origin: Vec2(x: x, y: y),
            size: Vec2(x: width, y: height)
        )
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
    var minX: Double {
        origin.x
    }

    /// The maximum x coordinate.
    ///
    /// ```swift
    /// let right = Rect(x: 10, y: 20, width: 30, height: 40).maxX
    /// ```
    var maxX: Double {
        origin.x + size.x
    }

    /// The minimum y coordinate.
    ///
    /// ```swift
    /// let top = Rect(x: 10, y: 20, width: 30, height: 40).minY
    /// ```
    var minY: Double {
        origin.y
    }

    /// The maximum y coordinate.
    ///
    /// ```swift
    /// let bottom = Rect(x: 10, y: 20, width: 30, height: 40).maxY
    /// ```
    var maxY: Double {
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
    func translated(by offset: Vec2) -> Rect {
        Rect(
            origin: Vec2(
                x: origin.x + offset.x,
                y: origin.y + offset.y
            ),
            size: size
        )
    }

    /// Returns a rectangle inset on every edge by the same amount.
    ///
    /// ```swift
    /// let inner = Rect(x: 0, y: 0, width: 100, height: 100).padding(8)
    /// ```
    func padding(_ amount: Double) -> Rect {
        padding(.all, amount)
    }

    /// Returns a rectangle inset on the selected edges.
    ///
    /// ```swift
    /// let inner = Rect(x: 0, y: 0, width: 100, height: 100)
    ///     .padding(.horizontal, 12)
    /// ```
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

    /// Returns whether this rectangle overlaps another rectangle.
    ///
    /// Touching edges without overlap return `false`.
    ///
    /// ```swift
    /// let player = Rect(x: 0, y: 0, width: 16, height: 16)
    /// let pickup = Rect(x: 8, y: 8, width: 8, height: 8)
    /// let overlaps = player.intersects(pickup)
    /// ```
    func intersects(_ other: Rect) -> Bool {
        minX < other.maxX
            && maxX > other.minX
            && minY < other.maxY
            && maxY > other.minY
    }
}
