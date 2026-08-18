import Swift

public struct CameraPose: Sendable {
    public var rotation: SIMD4<Float>
    public var zoom: Float
    public var target: SIMD3<Float>

    public init(
        rotation: SIMD4<Float>,
        zoom: Float,
        target: SIMD3<Float>
    ) {
        self.rotation = rotation
        self.zoom = zoom
        self.target = target
    }
}
