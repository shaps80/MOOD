import Swift

/// A two-dimensional floating-point vector used for positions, sizes, and movement.
///
/// Use `Vec2` anywhere Pixl needs platform-neutral 2D coordinates.
///
/// ```swift
/// let spawn = Vec2(x: 32, y: 48)
/// let velocity = Vec2(x: 90, y: 0)
/// ```
public struct Vec2: AdditiveArithmetic, Hashable, Codable, Sendable {
    /// The horizontal component.
    ///
    /// ```swift
    /// let point = Vec2(x: 12, y: 20)
    /// let x = point.x
    /// ```
    public var x: Double

    /// The vertical component.
    ///
    /// ```swift
    /// let point = Vec2(x: 12, y: 20)
    /// let y = point.y
    /// ```
    public var y: Double

    /// Creates a vector from horizontal and vertical components.
    ///
    /// ```swift
    /// let position = Vec2(x: 16, y: 24)
    /// ```
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public init(_ size: Double) {
        x = size
        y = size
    }

    /// A vector with both components set to zero.
    ///
    /// ```swift
    /// let origin = Vec2.zero
    /// ```
    public static let zero: Self = .init(
        x: .zero,
        y: .zero
    )

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
    /// Negates both vector components.
    ///
    /// ```swift
    /// let left = -Vec2(x: 1, y: 0)
    /// ```
    static prefix func - (vector: Vec2) -> Vec2 {
        Vec2(x: -vector.x, y: -vector.y)
    }

    /// Adds two vectors component-wise.
    ///
    /// ```swift
    /// let point = Vec2(x: 10, y: 20) + Vec2(x: 4, y: 2)
    /// ```
    static func + (lhs: Vec2, rhs: Vec2) -> Vec2 {
        Vec2(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    /// Adds the right vector into the left vector.
    ///
    /// ```swift
    /// var position = Vec2.zero
    /// position += Vec2(x: 1, y: 0)
    /// ```
    static func += (lhs: inout Vec2, rhs: Vec2) {
        lhs = lhs + rhs
    }

    /// Subtracts two vectors component-wise.
    ///
    /// ```swift
    /// let offset = Vec2(x: 10, y: 20) - Vec2(x: 4, y: 2)
    /// ```
    static func - (lhs: Vec2, rhs: Vec2) -> Vec2 {
        Vec2(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    /// Subtracts the right vector from the left vector.
    ///
    /// ```swift
    /// var position = Vec2(x: 10, y: 0)
    /// position -= Vec2(x: 1, y: 0)
    /// ```
    static func -= (lhs: inout Vec2, rhs: Vec2) {
        lhs = lhs - rhs
    }

    static func * (lhs: Vec2, rhs: Vec2) -> Vec2 {
        Vec2(x: lhs.x * rhs.x, y: lhs.y * rhs.y)
    }

    static func * (lhs: Vec2, rhs: Double) -> Vec2 {
        Vec2(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    static func * (lhs: Double, rhs: Vec2) -> Vec2 {
        rhs * lhs
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
