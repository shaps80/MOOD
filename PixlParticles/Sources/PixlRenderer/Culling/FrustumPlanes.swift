import Swift

struct FrustumPlanes: BitwiseCopyable {
    let left: SIMD4<Float>
    let right: SIMD4<Float>
    let bottom: SIMD4<Float>
    let top: SIMD4<Float>
    let near: SIMD4<Float>
    let far: SIMD4<Float>

    init(viewProjection matrix: Matrix4x4) {
        let x = Self.row(0, matrix: matrix)
        let y = Self.row(1, matrix: matrix)
        let z = Self.row(2, matrix: matrix)
        let w = Self.row(3, matrix: matrix)
        left = Self.normalized(w + x)
        right = Self.normalized(w - x)
        bottom = Self.normalized(w + y)
        top = Self.normalized(w - y)
        near = Self.normalized(z)
        far = Self.normalized(w - z)
    }

    private static func row(
        _ index: Int,
        matrix: Matrix4x4
    ) -> SIMD4<Float> {
        [
            matrix.x[index],
            matrix.y[index],
            matrix.z[index],
            matrix.w[index],
        ]
    }

    private static func normalized(_ plane: SIMD4<Float>) -> SIMD4<Float> {
        let length = (plane.x * plane.x
            + plane.y * plane.y
            + plane.z * plane.z).squareRoot()
        return length > 0 ? plane / length : plane
    }
}
