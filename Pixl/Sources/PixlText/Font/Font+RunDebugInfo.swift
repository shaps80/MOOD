extension Font {
    package struct RunDebugInfo: Sendable {
        package enum LineHeight: Hashable, Sendable {
            case natural
            case multiple(Float)
            case atLeast(Float)
            case exactly(Float)
        }

        package enum Direction: String, Hashable, Sendable {
            case leftToRight = "Left to right"
            case rightToLeft = "Right to left"
        }

        package struct FontInput: Sendable {
            package let font: Font
            package let fontBytes: [UInt8]
            package let fontID: String
            package let fontName: String
            package let direction: Direction

            package init(
                font: Font,
                fontBytes: [UInt8],
                fontID: String,
                fontName: String,
                direction: Direction = .leftToRight
            ) {
                self.font = font
                self.fontBytes = fontBytes
                self.fontID = fontID
                self.fontName = fontName
                self.direction = direction
            }
        }

        package struct Input: Sendable {
            package let sourceRange: Range<Int>
            package let font: FontInput

            package init(sourceRange: Range<Int>, font: FontInput) {
                self.sourceRange = sourceRange
                self.font = font
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
            package let lineIndex: Int
            package let runIndex: Int
            package let glyphID: UInt16
            package let sourceRange: Range<Int>
            package let advance: Float
            package let typographicBounds: GlyphDebugInfo.Bounds
            package let renderBounds: GlyphDebugInfo.Bounds?
        }

        package struct Break: Hashable, Sendable {
            package enum Kind: String, Hashable, Sendable {
                case allowed = "Allowed"
                case softHyphen = "Soft hyphen"
                case mandatory = "Mandatory"
            }

            package let sourceOffset: Int
            package let kind: Kind
        }

        package struct Word: Hashable, Sendable {
            package let lineIndex: Int
            package let source: String
            package let sourceRange: Range<Int>
            package let bounds: GlyphDebugInfo.Bounds
        }

        package struct Line: Hashable, Sendable {
            package let availableX: Float
            package let maximumWidth: Float
            package let consumedSourceRange: Range<Int>
            package let consumedGlyphRange: Range<Int>
            package let visibleGlyphRange: Range<Int>
            package let breakKind: Break.Kind
            package let advance: Float
            package let ascent: Float
            package let descent: Float
            package let leading: Float
            package let naturalAbove: Float
            package let naturalBelow: Float
            package let baselineY: Float
            package let baselineOffset: Float
            package let typographicBounds: GlyphDebugInfo.Bounds
            package let lineBounds: GlyphDebugInfo.Bounds
            package let renderBounds: GlyphDebugInfo.Bounds?
        }

        package struct Paragraph: Hashable, Sendable {
            package let source: String
            package let sourceRange: Range<Int>
            package let lineRange: Range<Int>
            package let bounds: GlyphDebugInfo.Bounds
            package let renderBounds: GlyphDebugInfo.Bounds?
            package let firstBaselineY: Float
            package let lastBaselineY: Float
        }

        package let runs: [Run]
        package let glyphs: [Glyph]
        package let words: [Word]
        package let breaks: [Break]
        package let lines: [Line]
        package let paragraphs: [Paragraph]
        package let status: LayoutStatus
    }
}
