import PixlGraphics

/// A source of base colour supplied to a material.
public enum Paint: Equatable, Sendable {
    /// One constant colour.
    case color(Color)
    /// A retained colour ramp with local placement.
    case gradient(GradientFill)
    /// A texture region and the sampling used to read it.
    case texture(Texture)
}

public extension Paint {
    /// Texture-backed paint input.
    struct Texture: Equatable, Sendable {
        public var region: TextureRegion
        public var sampling: TextureSampling

        public init(
            region: TextureRegion,
            sampling: TextureSampling = .init()
        ) {
            self.region = region
            self.sampling = sampling
        }
    }
}
