import Swift

public func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
    min(max(value, minValue), maxValue)
}
