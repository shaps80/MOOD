import simd

enum Projection: Hashable {
    case perspective(
        verticalFieldOfView: Float,
        near: Float,
        far: Float
    )
    case orthographic(
        halfHeight: Float,
        near: Float,
        far: Float
    )

    func magnified(by scale: Float) -> Self {
        precondition(scale > 0)

        switch self {
        case .perspective:
            return self

        case let .orthographic(halfHeight, near, far):
            return .orthographic(
                halfHeight: halfHeight / scale,
                near: near,
                far: far
            )
        }
    }

    func extendingFarPlane(to distance: Float) -> Self {
        switch self {
        case let .perspective(fieldOfView, near, far):
            return .perspective(
                verticalFieldOfView: fieldOfView,
                near: near,
                far: max(far, distance)
            )

        case .orthographic:
            return self
        }
    }

    func matrix(aspectRatio: Float) -> simd_float4x4 {
        switch self {
        case let .perspective(fieldOfView, near, far):
            precondition(fieldOfView > 0 && fieldOfView < .pi)
            precondition(near > 0 && far > near)

            let scale = 1 / tan(fieldOfView / 2)
            let depthScale = far / (near - far)
            let depthTranslation = far * near / (near - far)

            return simd_float4x4(columns: (
                [scale / aspectRatio, 0, 0, 0],
                [0, scale, 0, 0],
                [0, 0, depthScale, -1],
                [0, 0, depthTranslation, 0]
            ))

        case let .orthographic(halfHeight, near, far):
            precondition(halfHeight > 0)
            precondition(near > 0 && far > near)

            let halfWidth = halfHeight * aspectRatio
            let depthScale = 1 / (near - far)
            let depthTranslation = near / (near - far)

            return simd_float4x4(columns: (
                [1 / halfWidth, 0, 0, 0],
                [0, 1 / halfHeight, 0, 0],
                [0, 0, depthScale, 0],
                [0, 0, depthTranslation, 1]
            ))
        }
    }
}
