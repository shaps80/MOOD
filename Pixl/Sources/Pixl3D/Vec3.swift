import Swift

/// A compact three-dimensional single-precision vector.
public typealias Vec3 = SIMD3<Float>

/// Convenience values for three-dimensional vectors.
///
/// Use `Vec3` for positions, sizes, directions, and movement in 3D space.
///
/// ```swift
/// let spawn = Vec3(x: 32, y: 48, z: 4)
/// let velocity = Vec3(x: 90, y: 0, z: -10)
/// ```
public extension Vec3 {
    /// A vector with all components set to `1`.
    ///
    /// ```swift
    /// let scale = Vec3.one
    /// ```
    static let one: Self = .init(
        x: 1,
        y: 1,
        z: 1
    )
}

public extension Vec3 {
    /// Creates a vector with independently random components.
    ///
    /// - Parameters:
    ///   - x: Closed range used for the x component.
    ///   - y: Closed range used for the y component.
    ///   - z: Closed range used for the z component.
    /// - Returns: A vector whose components are sampled from their corresponding ranges.
    static func random(x: ClosedRange<Float>, y: ClosedRange<Float>, z: ClosedRange<Float>) -> Self {
        .init(
            x: Float.random(in: x),
            y: Float.random(in: y),
            z: Float.random(in: z)
        )
    }
}

public extension Vec3 {
    /// The Euclidean length of the vector.
    ///
    /// ```swift
    /// let speed = velocity.length
    /// ```
    var length: Float {
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
    /// - Parameter other: The vector to multiply component-wise before summing.
    /// - Returns: The scalar dot product of this vector and `other`.
    func dot(_ other: Self) -> Float {
        (x * other.x) + (y * other.y) + (z * other.z)
    }
}
