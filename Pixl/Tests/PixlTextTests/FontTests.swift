import Testing
@testable import PixlText

@Suite("Font")
struct FontTests {
    @Test("Modifiers preserve the original declaration")
    func modifiers() {
        let original = Font.system(size: 24)
        let derived = original.italic().weight(.semibold)

        #expect(original.descriptor.source == .system)
        #expect(original.descriptor.size == 24)
        #expect(original.descriptor.weight == .regular)
        #expect(original.descriptor.slant == .upright)
        #expect(derived.descriptor.weight == .semibold)
        #expect(derived.descriptor.slant == .italic)
    }

    @Test("System font resolves through the shared registry")
    func systemResolution() throws {
        let face = try Font.system(size: 24).resolvedFace

        #expect(face.metrics.unitsPerEm == 400)
        #expect(face.glyphCount > 0)
    }
}
