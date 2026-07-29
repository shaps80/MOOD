extension SFNT {
    final class Registry {
        private var faces: [FaceStorage] = []
        
        init() {}
        
        @discardableResult
        func register(bytes: [UInt8]) throws -> Face {
            let storage = try FaceStorage(bytes: bytes)
            let rawID = UInt32(faces.count)
            let face = Face(
                id: .init(rawValue: rawID),
                metrics: storage.metrics,
                glyphCount: storage.glyphCount,
                tableCount: storage.tableCount
            )
            faces.append(storage)
            return face
        }
        
        func glyphID(for scalar: Unicode.Scalar, in face: Face) -> GlyphID? {
            guard let storage = storage(for: face) else { return nil }
            return storage.glyphID(for: scalar)
        }
        
        func advance(for glyph: GlyphID, in face: Face, size: Float) -> Float? {
            precondition(size > 0)
            guard let storage = storage(for: face) else { return nil }
            let units = storage.advance(for: glyph)
            return Float(units) * size / Float(face.metrics.unitsPerEm)
        }

        func renderBounds(for glyph: GlyphID, in face: Face) -> GlyphBounds? {
            storage(for: face)?.renderBounds(for: glyph)
        }

        func glyphSubstitution(in face: Face) -> GlyphSubstitution? {
            storage(for: face)?.glyphSubstitution
        }
        
        private func storage(for face: Face) -> FaceStorage? {
            let index = Int(face.id.rawValue)
            guard faces.indices.contains(index) else { return nil }
            return faces[index]
        }
    }
}
