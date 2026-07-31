extension Font {
    package struct LayoutDebugInfo: Sendable {
        package enum LineHeight: Hashable, Sendable {
            case natural
            case multiple(Float)
            case atLeast(Float)
            case exactly(Float)
        }

        package enum Direction: Hashable, Sendable {
            case leftToRight
            case rightToLeft
        }

        package struct FontInput: Sendable {
            package let font: Font
            package let fontBytes: [UInt8]
            package let fontID: String
            package let direction: Direction

            package init(
                font: Font,
                fontBytes: [UInt8],
                fontID: String,
                direction: Direction = .leftToRight
            ) {
                self.font = font
                self.fontBytes = fontBytes
                self.fontID = fontID
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

        package struct Bounds: Hashable, Sendable {
            package let x: Float
            package let y: Float
            package let width: Float
            package let height: Float

            package init(x: Float, y: Float, width: Float, height: Float) {
                self.x = x
                self.y = y
                self.width = width
                self.height = height
            }
        }

        package struct Run: Hashable, Sendable {
            package let sourceRange: Range<Int>
            package let bounds: Bounds
        }

        package struct Paragraph: Hashable, Sendable {
            package let sourceRange: Range<Int>
            package let bounds: Bounds
        }

        package let runs: [Run]
        package let paragraphs: [Paragraph]
        package let bounds: Bounds
    }
}
