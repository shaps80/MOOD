import Swift

/// Linearly interpolates between two floating-point values.
/// - Parameters:
///   - source: Value returned when `delta` is `0`.
///   - target: Value returned when `delta` is `1`.
///   - delta: Unclamped interpolation amount.
/// - Returns: `source + (target - source) * delta`.
@inlinable
public func lerp<T: FloatingPoint>(from source: T, to target: T, by delta: T) -> T {
    source + (target - source) * delta
}
