import Swift

/// A two-dimensional floating-point vector used for positions, sizes, and movement.
///
/// Use `Vec2` anywhere Pixl needs platform-neutral 2D coordinates.
///
/// ```swift
/// let spawn = Vec2(x: 32, y: 48)
/// let velocity = Vec2(x: 90, y: 0)
/// ```
public struct Vec2: Equatable, Sendable {
    /// The horizontal component.
    ///
    /// ```swift
    /// let point = Vec2(x: 12, y: 20)
    /// let x = point.x
    /// ```
    public let x: Double

    /// The vertical component.
    ///
    /// ```swift
    /// let point = Vec2(x: 12, y: 20)
    /// let y = point.y
    /// ```
    public let y: Double

    /// Creates a vector from horizontal and vertical components.
    ///
    /// ```swift
    /// let position = Vec2(x: 16, y: 24)
    /// ```
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
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
}

extension Vec2 {
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

    private var length: Double {
        (x * x + y * y).squareRoot()
    }
}
