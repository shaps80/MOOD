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

@Suite("Packed position pair")
struct PositionPairTests {
    @Test("Uses two tightly packed three-component positions")
    func layout() {
        #expect(MemoryLayout<PositionPair>.size == 24)
        #expect(MemoryLayout<PositionPair>.stride == 24)
        #expect(MemoryLayout<PositionPair>.alignment == 4)
    }
}
