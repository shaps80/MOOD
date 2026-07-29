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

            for scalar in text.unicodeScalars {
                let glyph = sfnt.glyphID(for: scalar, in: face) ?? .init(rawValue: 0)
                let advance = sfnt.advance(
                    for: glyph,
                    in: face,
                    size: descriptor.size
                ) ?? 0

                body(
                    .init(
                        scalar: scalar,
                        glyphID: glyph.rawValue,
                        advance: advance,
                        bounds: .init(
                            x: x,
                            y: -metrics.ascent,
                            width: advance,
                            height: metrics.ascent + metrics.descent
                        )
                    )
                )
                x += advance
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
