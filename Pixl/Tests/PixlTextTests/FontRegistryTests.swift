import Foundation
import Testing
@testable import PixlText

@Suite("SFNT registry")
struct SFNTRegistryTests {
    @Test("Zapfino exposes real face metrics and glyph data")
    func zapfino() throws {
        let path = "/System/Library/Fonts/Supplemental/Zapfino.ttf"
        let bytes = Array(try Data(contentsOf: URL(filePath: path)))
        let registry = SFNT.Registry()
        let face = try registry.register(bytes: bytes)

        #expect(face.tableCount > 0)
        #expect(face.glyphCount > 0)
        #expect(face.metrics.unitsPerEm > 0)
        let metrics = face.metrics.scaled(to: 24)
        #expect(metrics.ascent > 0)
        #expect(metrics.descent >= 0)

        let glyph = try #require(registry.glyphID(for: "A", in: face))
        let advance = try #require(registry.advance(for: glyph, in: face, size: 24))
        #expect(advance > 0)
    }

    @Test("San Francisco variable instances interpolate metrics and outlines")
    func sanFranciscoVariations() throws {
        let path = "/System/Library/Fonts/SFNS.ttf"
        guard FileManager.default.fileExists(atPath: path) else { return }
        let bytes = Array(try Data(contentsOf: URL(filePath: path)))
        let registry = SFNT.Registry()
        let base = try registry.register(bytes: bytes)
        let axes = registry.variationAxes(in: base)
        let weight = try #require(axes.first(where: { $0.tag == 0x7767_6874 }))
        let light = try #require(registry.instance(
            of: base,
            settings: [(weight.tag, weight.minimum)]
        ))
        let heavy = try #require(registry.instance(
            of: base,
            settings: [(weight.tag, weight.maximum)]
        ))

        let glyph = try #require(registry.glyphID(for: "A", in: base))
        let lightAdvance = try #require(registry.advanceInFontUnits(for: glyph, in: light))
        let heavyAdvance = try #require(registry.advanceInFontUnits(for: glyph, in: heavy))
        let lightBounds = try #require(registry.renderBounds(for: glyph, in: light))
        let heavyBounds = try #require(registry.renderBounds(for: glyph, in: heavy))

        #expect(lightAdvance != heavyAdvance)
        #expect(lightBounds != heavyBounds)
    }

    @Test("San Francisco composite glyphs inherit variation geometry")
    func sanFranciscoCompositeVariations() throws {
        let path = "/System/Library/Fonts/SFNS.ttf"
        guard FileManager.default.fileExists(atPath: path) else { return }
        let bytes = Array(try Data(contentsOf: URL(filePath: path)))
        let registry = SFNT.Registry()
        let base = try registry.register(bytes: bytes)
        let weight = try #require(
            registry.variationAxes(in: base).first(where: { $0.tag == 0x7767_6874 })
        )
        let light = try #require(registry.instance(
            of: base,
            settings: [(weight.tag, weight.minimum)]
        ))
        let heavy = try #require(registry.instance(
            of: base,
            settings: [(weight.tag, weight.maximum)]
        ))
        let glyph = try #require(registry.glyphID(for: "é", in: base))

        #expect(
            registry.renderBounds(for: glyph, in: light)
                != registry.renderBounds(for: glyph, in: heavy)
        )
    }
}
