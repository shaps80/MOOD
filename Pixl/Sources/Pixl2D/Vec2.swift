import Swift

public typealias Vec2 = SIMD2<Double>

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
    public static let one: Self = .init(
        x: 1,
        y: 1
    )
}

public extension Vec2 {
    static func random(x: ClosedRange<Double>, y: ClosedRange<Double>) -> Vec2 {
        .init(
            x: Double.random(in: x),
            y: Double.random(in: y)
        )
    }
}

public extension Vec2 {
    func moving(toward target: Vec2, by distance: Double) -> Vec2 {
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
    var length: Double {
        (x * x + y * y).squareRoot()
    }

    /// The unit-length vector in the same direction, or `nil` for zero vectors.
    ///
    /// ```swift
    /// let direction = velocity.normalized
    /// ```
    var normalized: Vec2? {
        guard length > 0 else {
            return nil
        }

        return self * (1 / length)
    }

    /// Returns the dot product of two vectors.
    ///
    /// ```swift
    /// let facingAmount = facing.dot(direction)
    /// ```
    func dot(_ other: Vec2) -> Double {
        (x * other.x) + (y * other.y)
    }
}
