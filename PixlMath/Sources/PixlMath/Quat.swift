import Swift

public struct Quat: Hashable, Sendable {
    public static let identity = Self(vector: [0, 0, 0, 1])

    public var vector: SIMD4<Float>

    @inlinable @inline(__always)
    public init(vector: SIMD4<Float>) {
        self.vector = vector
    }

    @inlinable @inline(__always)
    public init(angle: Float, axis: SIMD3<Float>) {
        let axis = normalize(axis)
        let values = sinCos(angle * 0.5)
        vector = SIMD4<Float>(axis * values.sine, values.cosine)
    }

    @inlinable @inline(__always)
    public static func * (lhs: Self, rhs: Self) -> Self {
        let left = SIMD3<Float>(lhs.vector.x, lhs.vector.y, lhs.vector.z)
        let right = SIMD3<Float>(rhs.vector.x, rhs.vector.y, rhs.vector.z)
        return Self(
            vector: SIMD4<Float>(
                lhs.vector.w * right
                    + rhs.vector.w * left
                    + cross(left, right),
                lhs.vector.w * rhs.vector.w - dot(left, right)
            )
        )
    }
}

@inlinable @inline(__always)
public func normalize(_ value: Quat) -> Quat {
    let vector = value.vector
    let lengthSquared = vector.x * vector.x
        + vector.y * vector.y
        + vector.z * vector.z
        + vector.w * vector.w
    guard lengthSquared > 0 else { return .identity }
    return Quat(vector: vector / lengthSquared.squareRoot())
}

@inlinable @inline(__always)
public func act(_ rotation: Quat, _ value: SIMD3<Float>) -> SIMD3<Float> {
    let vector = rotation.vector
    let imaginary = SIMD3<Float>(vector.x, vector.y, vector.z)
    let offset = 2 * cross(
        imaginary,
        cross(imaginary, value) + vector.w * value
    )
    return value + offset
}

@inlinable @inline(__always)
public func slerp(_ start: Quat, _ end: Quat, _ amount: Float) -> Quat {
    var end = normalize(end)
    let start = normalize(start)
    var cosine = start.vector.x * end.vector.x
        + start.vector.y * end.vector.y
        + start.vector.z * end.vector.z
        + start.vector.w * end.vector.w

    if cosine < 0 {
        end.vector = -end.vector
        cosine = -cosine
    }
    if cosine > 0.9995 {
        return normalize(
            Quat(vector: start.vector + (end.vector - start.vector) * amount)
        )
    }

    cosine = min(max(cosine, -1), 1)
    let angle = acos(cosine)
    let angleSin = sin(angle)
    guard angleSin != 0 else { return start }
    let startScale = sin((1 - amount) * angle) / angleSin
    let endScale = sin(amount * angle) / angleSin
    return normalize(
        Quat(vector: start.vector * startScale + end.vector * endScale)
    )
}
