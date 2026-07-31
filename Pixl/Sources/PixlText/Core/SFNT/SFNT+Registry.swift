extension SFNT {
    final class Registry {
        private var faces: [FaceStorage] = []
        
        init() {}
        
        @discardableResult
        func register(bytes: [UInt8]) throws -> Face {
            let storage = try FaceStorage(bytes: bytes)
            let rawID = UInt32(faces.count)
            let face = storage.face(id: .init(rawValue: rawID), settings: [])
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
            let units = storage.advance(for: glyph, coordinates: face.normalizedCoordinates)
            return Float(units) * size / Float(face.metrics.unitsPerEm)
        }

        func advanceInFontUnits(for glyph: GlyphID, in face: Face) -> Int32? {
            storage(for: face)?.advance(for: glyph, coordinates: face.normalizedCoordinates)
        }

        func renderBounds(for glyph: GlyphID, in face: Face) -> GlyphBounds? {
            storage(for: face)?.renderBounds(for: glyph, coordinates: face.normalizedCoordinates)
        }

        func variationAxes(in face: Face) -> [VariationAxis] {
            storage(for: face)?.variations?.axes ?? []
        }

        func namedVariationInstances(in face: Face) -> [NamedVariationInstance] {
            storage(for: face)?.variations?.instances ?? []
        }

        func instance(of face: Face, settings: [(UInt32, Float)]) -> Face? {
            storage(for: face)?.face(id: face.id, settings: settings)
        }

        func glyphSubstitution(in face: Face) -> GlyphSubstitution? {
            storage(for: face)?.glyphSubstitution
        }

        func glyphPositioning(in face: Face) -> GlyphPositioning? {
            storage(for: face)?.glyphPositioning
        }

        func glyphDefinition(in face: Face) -> GlyphDefinition? {
            storage(for: face)?.glyphDefinition
        }
        
        private func storage(for face: Face) -> FaceStorage? {
            let index = Int(face.id.rawValue)
            guard faces.indices.contains(index) else { return nil }
            return faces[index]
        }
    }
}
