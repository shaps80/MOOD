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
}
