import PixlRenderer

/// Varies colours independently of depth to verify nearest-particle selection.
final class PaletteValidationBackend: Backend {
    private let base: DeviceBackend
    private let indices: HostBuffer
    private let palette: HostBuffer

    init(base: DeviceBackend, count: Int, alpha: Float) {
        self.base = base
        indices = HostBuffer(byteCount: count * 2)
        palette = HostBuffer(byteCount: 32)
        indices.withUnsafeBytes { bytes in
            let destination = UnsafeMutableRawPointer(mutating: bytes.baseAddress!).bindMemory(to: UInt16.self, capacity: count)
            for index in 0..<count { (destination + index).initialize(to: UInt16(index % 2)) }
        }
        palette.withUnsafeBytes { bytes in
            let destination = UnsafeMutableRawPointer(mutating: bytes.baseAddress!).bindMemory(to: SIMD4<Float>.self, capacity: 2)
            destination.initialize(to: SIMD4(1.5 * alpha, 0, 0, alpha))
            (destination + 1).initialize(to: SIMD4(0, 0.75 * alpha, alpha, alpha))
        }
    }

    func renderParticles(count: Int, buffers: ParticleBuffers, renderer: ParticleRenderer,
                         values: ParticleRenderValues, interpolation: Float,
                         cullingViewProjection: Matrix4x4, camera: CameraFrame) throws {
        try base.renderParticles(count: count, buffers: .init(capacity: buffers.capacity,
            displacements: buffers.displacements, displacementScale: buffers.displacementScale,
            currentPositions: buffers.currentPositions, colorIndices: indices,
            colorPalette: palette, ids: buffers.ids), renderer: renderer, values: values,
            interpolation: interpolation, cullingViewProjection: cullingViewProjection, camera: camera)
    }
}
