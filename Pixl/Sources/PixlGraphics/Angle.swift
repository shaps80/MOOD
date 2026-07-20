import Swift

/// An angle value stored in radians.
///
/// `Angle` mirrors SwiftUI's core `Angle` API while remaining independent of
/// SwiftUI and platform frameworks.
///
/// ```swift
/// let quarterTurn = Angle.degrees(90)
/// let halfTurn = Angle.radians(.pi)
/// ```
public struct Angle: Hashable, Comparable, Codable, Sendable {
    /// The angle value in radians.
    ///
    /// ```swift
    /// let angle = Angle.radians(.pi)
    /// let radians = angle.radians
    /// ```
    public var radians: Double

    /// The angle value in degrees.
    ///
    /// ```swift
    /// var angle = Angle.degrees(90)
    /// angle.degrees += 45
    /// ```
    @inline(__always)
    public var degrees: Double {
        get {
            radians * (180.0 / .pi)
        }
        set {
            radians = newValue * (.pi / 180.0)
        }
    }

    /// Creates a zero angle.
    ///
    /// ```swift
    /// let angle = Angle()
    /// ```
    @inline(__always)
    public init() {
        self.init(radians: 0)
    }

    /// Creates an angle from radians.
    ///
    /// ```swift
    /// let angle = Angle(radians: .pi)
    /// ```
    /// - Parameter radians: Angle value in radians.
    @inline(__always)
    public init(radians: Double) {
        self.radians = radians
    }

    /// Creates an angle from degrees.
    ///
    /// ```swift
    /// let angle = Angle(degrees: 180)
    /// ```
    /// - Parameter degrees: Angle value in degrees.
    @inline(__always)
    public init(degrees: Double) {
        self.init(radians: degrees * (.pi / 180.0))
    }

    /// Creates an angle from radians.
    ///
    /// ```swift
    /// let angle: Angle = .radians(.pi / 2)
    /// ```
    /// - Parameter radians: Angle value in radians.
    /// - Returns: An angle storing `radians`.
    @inline(__always)
    public static func radians(_ radians: Double) -> Angle {
        Angle(radians: radians)
    }

    /// Creates an angle from degrees.
    ///
    /// ```swift
    /// let angle: Angle = .degrees(90)
    /// ```
    /// - Parameter degrees: Angle value in degrees.
    /// - Returns: An angle converted from `degrees`.
    @inline(__always)
    public static func degrees(_ degrees: Double) -> Angle {
        Angle(degrees: degrees)
    }

    /// A zero angle.
    ///
    /// ```swift
    /// let angle: Angle = .zero
    /// ```
    @inline(__always)
    public static let zero = Angle()

    /// Returns whether the left angle is smaller than the right angle.
    ///
    /// ```swift
    /// let isQuarterTurn = Angle.degrees(90) < Angle.degrees(180)
    /// ```
    /// - Parameters:
    ///   - lhs: Angle on the left side of the comparison.
    ///   - rhs: Angle on the right side of the comparison.
    /// - Returns: `true` when `lhs` has fewer radians than `rhs`.
    @inline(__always)
    public static func < (lhs: Angle, rhs: Angle) -> Bool {
        lhs.radians < rhs.radians
    }
}

public extension Angle {
    /// Negates an angle.
    ///
    /// ```swift
    /// let clockwise = -Angle.degrees(90)
    /// ```
    /// - Parameter angle: Angle to negate.
    /// - Returns: An angle with the opposite sign.
    @inline(__always)
    static prefix func - (angle: Angle) -> Angle {
        Angle(radians: -angle.radians)
    }

    /// Adds two angles.
    ///
    /// ```swift
    /// let angle = Angle.degrees(90) + .degrees(45)
    /// ```
    /// - Parameters:
    ///   - lhs: First angle.
    ///   - rhs: Angle added to `lhs`.
    /// - Returns: The sum of both angles.
    @inline(__always)
    static func + (lhs: Angle, rhs: Angle) -> Angle {
        Angle(radians: lhs.radians + rhs.radians)
    }

    /// Adds the right angle into the left angle.
    ///
    /// ```swift
    /// var angle = Angle.zero
    /// angle += .degrees(90)
    /// ```
    /// - Parameters:
    ///   - lhs: Angle updated in place.
    ///   - rhs: Angle added to `lhs`.
    @inline(__always)
    static func += (lhs: inout Angle, rhs: Angle) {
        lhs = lhs + rhs
    }

    /// Subtracts one angle from another.
    ///
    /// ```swift
    /// let angle = Angle.degrees(180) - .degrees(90)
    /// ```
    /// - Parameters:
    ///   - lhs: Angle from which to subtract.
    ///   - rhs: Angle subtracted from `lhs`.
    /// - Returns: The angular difference.
    @inline(__always)
    static func - (lhs: Angle, rhs: Angle) -> Angle {
        Angle(radians: lhs.radians - rhs.radians)
    }

    /// Subtracts the right angle from the left angle.
    ///
    /// ```swift
    /// var angle = Angle.degrees(180)
    /// angle -= .degrees(90)
    /// ```
    /// - Parameters:
    ///   - lhs: Angle updated in place.
    ///   - rhs: Angle subtracted from `lhs`.
    @inline(__always)
    static func -= (lhs: inout Angle, rhs: Angle) {
        lhs = lhs - rhs
    }

    /// Scales an angle by a scalar.
    ///
    /// ```swift
    /// let angle = Angle.degrees(90) * 2
    /// ```
    /// - Parameters:
    ///   - lhs: Angle to scale.
    ///   - rhs: Scalar multiplier.
    /// - Returns: The scaled angle.
    @inline(__always)
    static func * (lhs: Angle, rhs: Double) -> Angle {
        Angle(radians: lhs.radians * rhs)
    }

    /// Scales an angle by a scalar.
    ///
    /// ```swift
    /// let angle = 2 * Angle.degrees(90)
    /// ```
    /// - Parameters:
    ///   - lhs: Scalar multiplier.
    ///   - rhs: Angle to scale.
    /// - Returns: The scaled angle.
    @inline(__always)
    static func * (lhs: Double, rhs: Angle) -> Angle {
        rhs * lhs
    }

    /// Scales an angle in place.
    ///
    /// ```swift
    /// var angle = Angle.degrees(90)
    /// angle *= 2
    /// ```
    /// - Parameters:
    ///   - lhs: Angle updated in place.
    ///   - rhs: Scalar multiplier.
    @inline(__always)
    static func *= (lhs: inout Angle, rhs: Double) {
        lhs = lhs * rhs
    }

    /// Divides an angle by a scalar.
    ///
    /// ```swift
    /// let angle = Angle.degrees(180) / 2
    /// ```
    /// - Parameters:
    ///   - lhs: Angle to divide.
    ///   - rhs: Scalar divisor.
    /// - Returns: The divided angle.
    @inline(__always)
    static func / (lhs: Angle, rhs: Double) -> Angle {
        Angle(radians: lhs.radians / rhs)
    }

    /// Divides an angle in place.
    ///
    /// ```swift
    /// var angle = Angle.degrees(180)
    /// angle /= 2
    /// ```
    /// - Parameters:
    ///   - lhs: Angle updated in place.
    ///   - rhs: Scalar divisor.
    @inline(__always)
    static func /= (lhs: inout Angle, rhs: Double) {
        lhs = lhs / rhs
    }
}
