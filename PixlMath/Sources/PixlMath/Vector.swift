import Swift

@inlinable @inline(__always)
public func dot(_ lhs: SIMD3<Float>, _ rhs: SIMD3<Float>) -> Float {
    lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
}

@inlinable @inline(__always)
public func cross(_ lhs: SIMD3<Float>, _ rhs: SIMD3<Float>) -> SIMD3<Float> {
    [
        lhs.y * rhs.z - lhs.z * rhs.y,
        lhs.z * rhs.x - lhs.x * rhs.z,
        lhs.x * rhs.y - lhs.y * rhs.x,
    ]
}

/// Returns the signed scalar cross product of two two-dimensional vectors.
@inlinable @inline(__always)
public func cross(_ lhs: SIMD2<Float>, _ rhs: SIMD2<Float>) -> Float {
    lhs.x * rhs.y - lhs.y * rhs.x
}

@inlinable @inline(__always)
public func normalize(_ value: SIMD3<Float>) -> SIMD3<Float> {
    let lengthSquared = dot(value, value)
    precondition(lengthSquared > 0)
    return value / lengthSquared.squareRoot()
}

@inlinable @inline(__always)
public func mix(_ start: Float, _ end: Float, _ amount: Float) -> Float {
    start + (end - start) * amount
}

@inlinable @inline(__always)
public func mix(
    _ start: SIMD3<Float>,
    _ end: SIMD3<Float>,
    _ amount: Float
) -> SIMD3<Float> {
    start + (end - start) * amount
}
