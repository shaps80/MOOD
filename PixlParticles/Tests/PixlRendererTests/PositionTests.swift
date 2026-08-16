import Testing
@testable import PixlRenderer

@Suite("Packed position")
struct PositionTests {
    @Test("Uses three tightly packed Float32 components")
    func layout() {
        #expect(MemoryLayout<Position>.size == 12)
        #expect(MemoryLayout<Position>.stride == 12)
        #expect(MemoryLayout<Position>.alignment == 4)
    }
}
