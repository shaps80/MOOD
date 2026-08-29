import Swift

/// A compact two-dimensional single-precision vector.
public typealias Vec2 = SIMD2<Float>

/// A two-dimensional floating-point vector used for positions, sizes, and movement.
///
/// Use `Vec2` anywhere Pixl needs platform-neutral 2D coordinates.
///
/// ```swift
/// let spawn = Vec2(x: 32, y: 48)
/// let velocity = Vec2(x: 90, y: 0)
/// ```
public extension Vec2 {
    /// A vector with both components set to 1.
    ///
    /// ```swift
    /// let origin = Vec2.one
    /// ```
    static let one: Self = .init(
        x: 1,
        y: 1
    )

    /// A sentinel vector that cannot represent a usable coordinate.
    static let invalid: Self = .init(repeating: .nan)

    /// Whether both components are finite usable values.
    var isValid: Bool {
        x.isFinite && y.isFinite
    }
}

public extension Vec2 {
    /// Creates a vector with independently random components.
    ///
    /// - Parameters:
    ///   - x: Closed range used for the x component.
    ///   - y: Closed range used for the y component.
    /// - Returns: A vector whose components are sampled from their corresponding ranges.
    static func random(x: ClosedRange<Float>, y: ClosedRange<Float>) -> Self {
        .init(
            x: Float.random(in: x),
            y: Float.random(in: y)
        )
    }
}

public extension Vec2 {
    /// Moves toward a target without travelling past it.
    ///
    /// - Parameters:
    ///   - target: Destination to approach.
    ///   - distance: Maximum distance to travel. Nonpositive values leave the vector unchanged.
    /// - Returns: The moved position, or `target` when it lies within `distance`.
    func moving(toward target: Self, by distance: Float) -> Self {
        guard distance > 0 else { return self }

        let delta = Vec2(
            x: target.x - x,
            y: target.y - y
        )
        let length = delta.length

        guard length > distance else {
            return target
        }

        let scale = distance / length
        return Vec2(
            x: x + (delta.x * scale),
            y: y + (delta.y * scale)
        )
    }

    /// The Euclidean length of the vector.
    ///
    /// ```swift
    /// let speed = velocity.length
    /// ```
    var length: Float {
        (x * x + y * y).squareRoot()
    }

    /// The unit-length vector in the same direction, or `zero` for zero vectors.
    ///
    /// ```swift
    /// let direction = velocity.normalized
    /// ```
    var normalized: Vec2 {
        let length = length
        guard length.isFinite, length > 0 else { return .zero }
        return self / length
    }

    /// Returns the dot product of two vectors.
    ///
    /// ```swift
    /// let facingAmount = facing.dot(direction)
    /// ```
    /// - Parameter other: The vector to multiply component-wise before summing.
    /// - Returns: The scalar dot product of this vector and `other`.
    func dot(_ other: Vec2) -> Float {
        (x * other.x) + (y * other.y)
    }
}
