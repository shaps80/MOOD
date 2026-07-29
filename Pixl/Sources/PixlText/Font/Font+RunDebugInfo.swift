extension Font {
    package struct RunDebugInfo: Sendable {
        package enum Direction: String, Hashable, Sendable {
            case leftToRight = "Left to right"
            case rightToLeft = "Right to left"
        }

        package struct Input: Sendable {
            package let sourceRange: Range<Int>
            package let font: Font
            package let fontBytes: [UInt8]
            package let fontID: String
            package let fontName: String
            package let direction: Direction

            package init(
                sourceRange: Range<Int>,
                font: Font,
                fontBytes: [UInt8],
                fontID: String,
                fontName: String,
                direction: Direction = .leftToRight
            ) {
                self.sourceRange = sourceRange
                self.font = font
                self.fontBytes = fontBytes
                self.fontID = fontID
                self.fontName = fontName
                self.direction = direction
            }
        }

        package struct Run: Hashable, Sendable {
            package let source: String
            package let sourceRange: Range<Int>
            package let glyphRange: Range<Int>
            package let fontName: String
            package let size: Float
            package let direction: Direction
            package let script: String
        }

        package struct Glyph: Hashable, Sendable {
            package let runIndex: Int
            package let glyphID: UInt16
            package let sourceRange: Range<Int>
            package let advance: Float
            package let typographicBounds: GlyphDebugInfo.Bounds
            package let renderBounds: GlyphDebugInfo.Bounds?
        }

        package let runs: [Run]
        package let glyphs: [Glyph]
    }
}
