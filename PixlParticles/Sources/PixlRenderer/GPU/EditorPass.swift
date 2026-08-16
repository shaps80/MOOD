import Swift

final class EditorPass {
    private let groundPlane: GroundPlanePass

    init(platform: any Platform) throws {
        groundPlane = try GroundPlanePass(platform: platform)
    }

    func encode(
        groundPlane settings: GroundPlane,
        viewProjection _: Matrix4x4,
        into encoder: any RenderEncoder
    ) {
        guard settings.isVisible else { return }
        groundPlane.encode(
            settings: settings,
            into: encoder
        )
    }
}
