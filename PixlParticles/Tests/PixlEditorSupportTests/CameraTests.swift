import PixlEditorSupport
import Testing

@Suite("Editor camera")
struct CameraTests {
    @Test("Projects the orbit target to the viewport centre")
    func projectsTarget() throws {
        let orbit = CameraPreset.perspectiveOrbit
        let viewport = try #require(
            orbit.camera().viewport(for: [1_000, 500])
        )
        let projected = try #require(viewport.project(orbit.target))

        #expect(abs(projected.x - 500) < 0.001)
        #expect(abs(projected.y - 250) < 0.001)
    }

}
