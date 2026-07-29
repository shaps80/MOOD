import Foundation

extension Font {
    final class Registry: @unchecked Sendable {
        static let shared = Registry()

        private static let systemURL = URL(filePath: "/System/Library/Fonts/Supplemental/Zapfino.ttf")

        private let lock = NSLock()
        private let sfnt = SFNT.Registry()
        private var systemFace: SFNT.Face?

        private init() {}

        func face(for descriptor: Descriptor) throws -> SFNT.Face {
            switch descriptor.source {
            case .system:
                return try loadSystemFace()
            }
        }

        func forEachGlyph(
            in text: String,
            descriptor: Descriptor,
            _ body: (GlyphDebugInfo) -> Void
        ) throws {
            let face = try face(for: descriptor)
            let metrics = face.metrics.scaled(to: descriptor.size)
            var x: Float = 0
            var sourceOffset = 0
            var glyphIndex = 0

            for scalar in text.unicodeScalars {
                let sourceRange = sourceOffset..<(sourceOffset + utf8Length(of: scalar))
                let glyphRange = glyphIndex..<(glyphIndex + 1)
                let glyph = sfnt.glyphID(for: scalar, in: face) ?? .init(rawValue: 0)
                let advance = sfnt.advance(
                    for: glyph,
                    in: face,
                    size: descriptor.size
                ) ?? 0
                let scale = descriptor.size / Float(face.metrics.unitsPerEm)
                let rawRenderBounds = sfnt.renderBounds(for: glyph, in: face)

                body(
                    .init(
                        scalar: scalar,
                        glyphID: glyph.rawValue,
                        cluster: .init(
                            sourceRange: sourceRange,
                            glyphRange: glyphRange
                        ),
                        advance: advance,
                        typographicBounds: .init(
                            x: x,
                            y: -metrics.ascent,
                            width: advance,
                            height: metrics.ascent + metrics.descent
                        ),
                        renderBounds: rawRenderBounds.map {
                            .init(
                                x: x + Float($0.xMin) * scale,
                                y: -Float($0.yMax) * scale,
                                width: Float($0.xMax - $0.xMin) * scale,
                                height: Float($0.yMax - $0.yMin) * scale
                            )
                        }
                    )
                )
                x += advance
                sourceOffset = sourceRange.upperBound
                glyphIndex = glyphRange.upperBound
            }
        }

        private func utf8Length(of scalar: Unicode.Scalar) -> Int {
            switch scalar.value {
            case ...0x7F: 1
            case ...0x7FF: 2
            case ...0xFFFF: 3
            default: 4
            }
        }

        private func loadSystemFace() throws -> SFNT.Face {
            lock.lock()
            defer { lock.unlock() }

            if let systemFace {
                return systemFace
            }

            let bytes = try Array(Data(contentsOf: Self.systemURL))
            let face = try sfnt.register(bytes: bytes)
            systemFace = face
            return face
        }
    }
}
