extension Font {
    struct Descriptor: Hashable, Sendable {
        enum Source: Hashable, Sendable {
            case system
        }

        var source: Source
        var size: Float
        var weight: Weight
        var slant: Slant

        init(source: Source, size: Float, weight: Weight) {
            self.source = source
            self.size = size
            self.weight = weight
            slant = .upright
        }
    }
}
