import Swift

/// Identical visibility inputs for direct vertex rejection and diagnostic counting.
struct DirectVisibility: BitwiseCopyable {
    let viewProjection: Matrix4x4
    let frustum: FrustumPlanes
    let bounds: SIMD4<Float>
    let modes: SIMD4<UInt32>

    init(viewProjection: Matrix4x4, renderer: ParticleRenderer,
         values: ParticleRenderValues, viewport: ViewportSize,
         cullingBounds: CullingBounds) {
        self.viewProjection = viewProjection
        frustum = .init(viewProjection: viewProjection)
        bounds = [cullingBounds.scale * 0.5, cullingBounds.baseHeight,
                  0.5 * (values.size.x * values.size.x
                       + values.size.y * values.size.y).squareRoot(), 0]
        modes = [CullingMode(renderer: renderer).rawValue,
                 cullingBounds.isEnabled ? 1 : 0, viewport.width, viewport.height]
    }
}
