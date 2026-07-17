import Swift

@inlinable
public func lerp<T: FloatingPoint>(from source: T, to target: T, by delta: T) -> T {
    source + (target - source) * delta
}
