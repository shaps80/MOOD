import Swift

public struct Matrix4x4: BitwiseCopyable, Sendable {
    public static let identity = Self(
        x: [1, 0, 0, 0],
        y: [0, 1, 0, 0],
        z: [0, 0, 1, 0],
        w: [0, 0, 0, 1]
    )

    public let x: SIMD4<Float>
    public let y: SIMD4<Float>
    public let z: SIMD4<Float>
    public let w: SIMD4<Float>

    public init(
        x: SIMD4<Float>,
        y: SIMD4<Float>,
        z: SIMD4<Float>,
        w: SIMD4<Float>
    ) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
}
