import Swift

public typealias Vec3 = SIMD3<Double>

/// A two-dimensional floating-point vector used for positions, sizes, and movement.
///
/// Use `Vec2` anywhere Pixl needs platform-neutral 2D coordinates.
///
/// ```swift
/// let spawn = Vec2(x: 32, y: 48)
/// let velocity = Vec2(x: 90, y: 0)
/// ```
public extension Vec3 {
    /// A vector with both components set to 1.
    ///
    /// ```swift
    /// let origin = Vec2.one
    /// ```
    public static let one: Self = .init(
        x: 1,
        y: 1,
        z: 1
    )
}

public extension Vec3 {
    static func random(x: ClosedRange<Double>, y: ClosedRange<Double>, z: ClosedRange<Double>) -> Self {
        .init(
            x: Double.random(in: x),
            y: Double.random(in: y),
            z: Double.random(in: z)
        )
    }
}

public extension Vec3 {
    /// The Euclidean length of the vector.
    ///
    /// ```swift
    /// let speed = velocity.length
    /// ```
    var length: Double {
        (x * x + y * y + z * z).squareRoot()
    }

    /// The unit-length vector in the same direction, or `nil` for zero vectors.
    ///
    /// ```swift
    /// let direction = velocity.normalized
    /// ```
    var normalized: Self? {
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
    func dot(_ other: Self) -> Double {
        (x * other.x) + (y * other.y) + (z * other.z)
    }
}
