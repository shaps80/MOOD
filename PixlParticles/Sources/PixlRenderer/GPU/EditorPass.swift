import Swift

final class EditorPass {
    private let groundPlane: GroundPlanePass
    private let cullingBounds: CullingBoundsPass
    private let cameraFrustum: CameraFrustumPass

    init(platform: any Platform) throws {
        groundPlane = try GroundPlanePass(platform: platform)
        cullingBounds = try CullingBoundsPass(platform: platform)
        cameraFrustum = try CameraFrustumPass(platform: platform)
    }

    func encode(
        groundPlane settings: GroundPlane,
        cullingBounds bounds: CullingBounds,
        cameraFrustum frustum: CameraFrustum,
        viewProjection: Matrix4x4,
        into encoder: any RenderEncoder
    ) {
        if settings.isVisible {
            groundPlane.encode(
                settings: settings,
                into: encoder
            )
        }
        if bounds.isVisible {
            cullingBounds.encode(
                bounds: bounds,
                viewProjection: viewProjection,
                into: encoder
            )
        }
        if frustum.isVisible {
            cameraFrustum.encode(
                frustum: frustum,
                viewProjection: viewProjection,
                into: encoder
            )
        }
    }
}
