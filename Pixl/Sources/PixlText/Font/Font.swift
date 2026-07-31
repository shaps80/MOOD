public struct Font: Hashable, Sendable {
    var descriptor: Descriptor

    public static func system(size: Float, weight: Weight = .regular) -> Self {
        precondition(size > 0)
        return .init(descriptor: .init(source: .system, size: size, weight: weight))
    }

    public func italic() -> Self {
        replacingDescriptor { $0.slant = .italic }
    }

    public func bold() -> Self {
        weight(.bold)
    }

    public func weight(_ weight: Weight) -> Self {
        replacingDescriptor { $0.weight = weight }
    }

    public func variation(_ tag: String, value: Float) -> Self {
        guard let rawTag = Self.rawTag(tag) else { return self }
        return replacingDescriptor { descriptor in
            if let index = descriptor.variations.firstIndex(where: { $0.tag == rawTag }) {
                descriptor.variations[index].value = value
            } else {
                descriptor.variations.append(.init(tag: rawTag, value: value))
                descriptor.variations.sort { $0.tag < $1.tag }
            }
        }
    }

    var resolvedFace: SFNT.Face {
        get throws {
            try Registry.shared.face(for: descriptor)
        }
    }

    private func replacingDescriptor(_ update: (inout Descriptor) -> Void) -> Self {
        var copy = self
        update(&copy.descriptor)
        return copy
    }

    private init(descriptor: Descriptor) {
        self.descriptor = descriptor
    }

    static func rawTag(_ tag: String) -> UInt32? {
        let bytes = Array(tag.utf8)
        guard bytes.count == 4 else { return nil }
        return UInt32(bytes[0]) << 24
            | UInt32(bytes[1]) << 16
            | UInt32(bytes[2]) << 8
            | UInt32(bytes[3])
    }
}
