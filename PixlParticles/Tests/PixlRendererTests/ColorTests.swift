import Testing
@testable import PixlRenderer

@Suite("Packed colour")
struct ColorTests {
    @Test("Uses four tightly packed Float16 components")
    func layout() {
        #expect(MemoryLayout<Color>.size == 8)
        #expect(MemoryLayout<Color>.stride == 8)
        #expect(MemoryLayout<Color>.alignment == 2)
    }

    @Test("Stores premultiplied linear HDR colour")
    func values() {
        let color = Color(
            premultipliedRed: 2,
            premultipliedGreen: 1,
            premultipliedBlue: 0.5,
            alpha: 0.5
        )

        #expect(color.red.bitPattern == 0x4000)
        #expect(color.green.bitPattern == 0x3c00)
        #expect(color.blue.bitPattern == 0x3800)
        #expect(color.alpha.bitPattern == 0x3800)
    }
}
