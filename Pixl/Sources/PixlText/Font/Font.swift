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
}
