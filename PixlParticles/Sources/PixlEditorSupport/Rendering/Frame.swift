import PixlRenderer

public struct Frame: Sendable {
    public var viewProjection: Matrix4x4
    public var groundPlane: GroundPlane
    public var wireBox: WireBox
    public var cameraFrustum: CameraFrustum

    public init(
        viewProjection: Matrix4x4 = .identity,
        groundPlane: GroundPlane = .init(),
        wireBox: WireBox = .init(),
        cameraFrustum: CameraFrustum = .init()
    ) {
        self.viewProjection = viewProjection
        self.groundPlane = groundPlane
        self.wireBox = wireBox
        self.cameraFrustum = cameraFrustum
    }
}
