extension Font {
    struct Descriptor: Hashable, Sendable {
        struct Variation: Hashable, Sendable {
            let tag: UInt32
            var value: Float
        }

        enum Source: Hashable, Sendable {
            case system
        }

        var source: Source
        var size: Float
        var weight: Weight
        var slant: Slant
        var variations: [Variation]

        init(source: Source, size: Float, weight: Weight) {
            self.source = source
            self.size = size
            self.weight = weight
            slant = .upright
            variations = []
        }
    }
}
