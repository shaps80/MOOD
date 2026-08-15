import simd

enum Projection: Hashable {
    case perspective
    case orthographic

    func matrix(
        aspectRatio: Float
    ) -> simd_float4x4 {
        let near: Float = 0.1
        let far: Float = 2_000

        switch self {
        case .perspective:
            let fieldOfView = Float.pi * 50 / 180
            let scale = 1 / tan(fieldOfView / 2)
            let depthScale = far / (near - far)
            let depthTranslation = far * near / (near - far)

            return simd_float4x4(columns: (
                [scale / aspectRatio, 0, 0, 0],
                [0, scale, 0, 0],
                [0, 0, depthScale, -1],
                [0, 0, depthTranslation, 0]
            ))

        case .orthographic:
            let verticalSize: Float = 350
            let horizontalSize = verticalSize * aspectRatio
            let depthScale = 1 / (near - far)
            let depthTranslation = near / (near - far)

            return simd_float4x4(columns: (
                [2 / horizontalSize, 0, 0, 0],
                [0, 2 / verticalSize, 0, 0],
                [0, 0, depthScale, 0],
                [0, 0, depthTranslation, 1]
            ))
        }
    }
}
