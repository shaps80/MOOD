public extension SFNT {
    final class Registry {
        private var faces: [FaceStorage] = []
        
        public init() {}
        
        @discardableResult
        public func register(bytes: [UInt8]) throws -> Face {
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
        
        public func glyphID(for scalar: Unicode.Scalar, in face: Face) -> GlyphID? {
            guard let storage = storage(for: face) else { return nil }
            return storage.glyphID(for: scalar)
        }
        
        public func advance(for glyph: GlyphID, in face: Face, size: Float) -> Float? {
            precondition(size > 0)
            guard let storage = storage(for: face) else { return nil }
            let units = storage.advance(for: glyph)
            return Float(units) * size / Float(face.metrics.unitsPerEm)
        }
        
        private func storage(for face: Face) -> FaceStorage? {
            let index = Int(face.id.rawValue)
            guard faces.indices.contains(index) else { return nil }
            return faces[index]
        }
    }
}
