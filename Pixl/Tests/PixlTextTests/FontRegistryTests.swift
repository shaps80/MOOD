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
}
