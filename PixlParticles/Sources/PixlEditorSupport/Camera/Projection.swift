import PixlMath
import PixlRenderer
import Swift

public enum Projection: Hashable, Sendable {
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

    public func magnified(by scale: Float) -> Self {
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

    public func extendingFarPlane(to distance: Float) -> Self {
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

    func matrices(aspectRatio: Float) -> (
        projection: Matrix4x4,
        inverse: Matrix4x4
    ) {
        switch self {
        case let .perspective(fieldOfView, near, far):
            precondition(fieldOfView > 0 && fieldOfView < .pi)
            precondition(near > 0 && far > near)
            let scale = 1 / tan(fieldOfView / 2)
            let xScale = scale / aspectRatio
            let depthScale = far / (near - far)
            let depthTranslation = far * near / (near - far)
            return (
                Matrix4x4(
                    x: [xScale, 0, 0, 0],
                    y: [0, scale, 0, 0],
                    z: [0, 0, depthScale, -1],
                    w: [0, 0, depthTranslation, 0]
                ),
                Matrix4x4(
                    x: [1 / xScale, 0, 0, 0],
                    y: [0, 1 / scale, 0, 0],
                    z: [0, 0, 0, 1 / depthTranslation],
                    w: [0, 0, -1, depthScale / depthTranslation]
                )
            )

        case let .orthographic(halfHeight, near, far):
            precondition(halfHeight > 0)
            precondition(near > 0 && far > near)
            let halfWidth = halfHeight * aspectRatio
            let depthScale = 1 / (near - far)
            let depthTranslation = near / (near - far)
            return (
                Matrix4x4(
                    x: [1 / halfWidth, 0, 0, 0],
                    y: [0, 1 / halfHeight, 0, 0],
                    z: [0, 0, depthScale, 0],
                    w: [0, 0, depthTranslation, 1]
                ),
                Matrix4x4(
                    x: [halfWidth, 0, 0, 0],
                    y: [0, halfHeight, 0, 0],
                    z: [0, 0, 1 / depthScale, 0],
                    w: [0, 0, -depthTranslation / depthScale, 1]
                )
            )
        }
    }
}
