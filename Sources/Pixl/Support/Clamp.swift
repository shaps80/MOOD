import Swift

/// Restricts a value to a closed numeric range.
///
/// ```swift
/// let axis = clamp(rawAxis, min: -1, max: 1)
/// let alpha = clamp(fade, min: 0, max: 1)
/// ```
public func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
    min(max(value, minValue), maxValue)
}
