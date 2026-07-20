import PixlMathC
import Swift

/// The sine and cosine of one angle, calculated together.
public struct SinCos<Scalar: Sendable>: Sendable {
    /// The angle's sine.
    public let sine: Scalar
    /// The angle's cosine.
    public let cosine: Scalar

    /// Creates a paired sine and cosine result.
    ///
    /// - Parameters:
    ///   - sine: The angle's sine.
    ///   - cosine: The angle's cosine.
    public init(sine: Scalar, cosine: Scalar) {
        self.sine = sine
        self.cosine = cosine
    }
}

/// Returns the sine of a single-precision angle.
/// - Parameter radians: The angle, in radians.
/// - Returns: The sine of `radians`.
public func sin(_ radians: Float) -> Float {
    pixl_sinf(radians)
}

/// Returns the cosine of a single-precision angle.
/// - Parameter radians: The angle, in radians.
/// - Returns: The cosine of `radians`.
public func cos(_ radians: Float) -> Float {
    pixl_cosf(radians)
}

/// Calculates the sine and cosine of a single-precision angle together.
/// - Parameter radians: The angle, in radians.
/// - Returns: The paired sine and cosine of `radians`.
public func sinCos(_ radians: Float) -> SinCos<Float> {
    let value = pixl_sin_cosf(radians)
    return .init(sine: value.sine, cosine: value.cosine)
}

/// Returns the sine of a double-precision angle.
/// - Parameter radians: The angle, in radians.
/// - Returns: The sine of `radians`.
public func sin(_ radians: Double) -> Double {
    pixl_sin(radians)
}

/// Returns the cosine of a double-precision angle.
/// - Parameter radians: The angle, in radians.
/// - Returns: The cosine of `radians`.
public func cos(_ radians: Double) -> Double {
    pixl_cos(radians)
}

/// Calculates the sine and cosine of a double-precision angle together.
/// - Parameter radians: The angle, in radians.
/// - Returns: The paired sine and cosine of `radians`.
public func sinCos(_ radians: Double) -> SinCos<Double> {
    let value = pixl_sin_cos(radians)
    return .init(sine: value.sine, cosine: value.cosine)
}
