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

    @Test("Package debug API emits unshaped glyph bounds")
    func glyphDebugging() throws {
        var glyphs: [Font.GlyphDebugInfo] = []
        try Font.system(size: 48).forEachGlyph(in: "Hello, world!") {
            glyphs.append($0)
        }

        #expect(glyphs.count == 13)
        #expect(glyphs.first?.scalar == "H")
        #expect(glyphs.allSatisfy { $0.typographicBounds.height > 0 })
        #expect(glyphs.dropFirst().allSatisfy { $0.typographicBounds.x > 0 })
        #expect(glyphs.first?.renderBounds != nil)
    }

    @Test("Clusters retain UTF-8 source and glyph ranges")
    func clusters() throws {
        var glyphs: [Font.GlyphDebugInfo] = []
        try Font.system(size: 48).forEachGlyph(in: "Aé😀") {
            glyphs.append($0)
        }

        #expect(glyphs.map(\.cluster.sourceRange) == [0..<1, 1..<3, 3..<7])
        #expect(glyphs.map(\.cluster.glyphRange) == [0..<1, 1..<2, 2..<3])
    }
}
