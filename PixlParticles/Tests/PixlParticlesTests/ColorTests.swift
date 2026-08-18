import Testing
@testable import PixlParticles

@Suite("Authored colour")
struct ColorTests {
    @Test("Preserves straight linear HDR components")
    func values() {
        let color = Color(red: -0.25, green: 0.5, blue: 4, alpha: 0.75)

        #expect(color.red == -0.25)
        #expect(color.green == 0.5)
        #expect(color.blue == 4)
        #expect(color.alpha == 0.75)
    }

    @Test("Defaults to opaque white")
    func white() {
        #expect(Color.white == Color(red: 1, green: 1, blue: 1, alpha: 1))
    }
}
