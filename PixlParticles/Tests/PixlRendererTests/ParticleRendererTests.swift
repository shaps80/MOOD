import Foundation
import Testing
@testable import PixlRenderer

@Suite("Particle renderer configuration")
struct ParticleRendererConfigurationTests {
    @Test("Defaults preserve the existing point path")
    func defaults() {
        let renderer = ParticleRenderer()
        let values = ParticleRenderValues()

        #expect(renderer.mode == .point)
        #expect(renderer.billboard.sizeSpace == .world)
        #expect(renderer.billboard.facing == .camera)
        #expect(values.size == [1, 2])
        #expect(values.rotation == 0)
    }

    @Test("Authored renderer settings round-trip through documents")
    func codingRoundTrip() throws {
        let renderer = ParticleRenderer(
            mode: .billboard,
            billboard: .init(
                sizeSpace: .screen,
                facing: .cameraPosition
            )
        )

        let encoded = try JSONEncoder().encode(renderer)
        let decoded = try JSONDecoder().decode(
            ParticleRenderer.self,
            from: encoded
        )

        #expect(decoded == renderer)
    }

    @Test("Camera frame matches the GPU constant-block layout")
    func cameraFrameLayout() {
        #expect(MemoryLayout<CameraFrame>.stride == 128)
        #expect(MemoryLayout<CameraFrame>.alignment == 16)
    }
}
