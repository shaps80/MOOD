import Swift

/// Restricts a value to a closed numeric range.
///
/// ```swift
/// let axis = clamp(rawAxis, min: -1, max: 1)
/// let alpha = clamp(fade, min: 0, max: 1)
/// ```
/// - Parameters:
///   - value: Value to constrain.
///   - minValue: Lower bound returned when `value` is smaller.
///   - maxValue: Upper bound returned when `value` is larger.
/// - Returns: `value` constrained to the inclusive bounds.
public func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
    min(max(value, minValue), maxValue)
}
