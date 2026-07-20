import PixlGraphics

/// A mutable, value-semantic description of one sprite.
public struct Sprite {
    /// Texture region displayed by the sprite.
    public var region: TextureRegion
    /// Sampling and composition applied when rendering.
    public var material: Material
    /// Coarse render layer. Lower layers render first.
    public var layer: RenderLayer
    /// Ordering within `layer`. Lower values render first.
    public var order: UInt32
    /// Whether texture coordinates are mirrored horizontally.
    public var isFlipped: Bool

    /// Texture asset containing `region`.
    public var asset: TextureAsset {
        region.asset
    }

    /// Creates a sprite from a texture region and optional rendering properties.
    ///
    /// ```swift
    /// var sprite = Sprite(region: sheet.region(column: 0, row: 0))
    /// sprite.layer = 10
    /// sprite.isFlipped = true
    /// ```
    ///
    /// - Parameters:
    ///   - region: Texture region displayed by the sprite.
    ///   - material: Texture sampling and composition properties.
    ///   - layer: Coarse render layer. Lower layers render first.
    ///   - order: Ordering within `layer`. Equal values preserve submission order.
    ///   - isFlipped: Whether to mirror texture coordinates horizontally.
    public init(
        region: TextureRegion,
        material: Material = .init(),
        layer: RenderLayer = 0,
        order: UInt32 = 0,
        isFlipped: Bool = false
    ) {
        self.region = region
        self.material = material
        self.layer = layer
        self.order = order
        self.isFlipped = isFlipped
    }
}

public extension Sprite {
    /// Describes how the sprite's texture region is sampled and composed.
    struct Material: Hashable, Sendable {
        /// Filtering used when the texture is minified or magnified.
        public var filtering: Filtering
        /// Addressing used outside the texture-coordinate range.
        public var addressing: Addressing
        /// Composition used when writing over the render target.
        public var blendMode: BlendMode

        /// Creates sprite material properties.
        /// - Parameters:
        ///   - filtering: Filtering used when shrinking or enlarging the texture.
        ///   - addressing: Horizontal and vertical out-of-range sampling behaviour.
        ///   - blendMode: Composition used over the render target.
        public init(
            filtering: Filtering = .nearest,
            addressing: Addressing = .clampToEdge,
            blendMode: BlendMode = .normal
        ) {
            self.filtering = filtering
            self.addressing = addressing
            self.blendMode = blendMode
        }
    }
}

public extension Sprite.Material {
    /// Texture filtering for shrinking and enlarging the sprite image.
    struct Filtering: Hashable, Sendable {
        /// Filter used when the texture is displayed smaller than its source.
        public var minification: Filter
        /// Filter used when the texture is displayed larger than its source.
        public var magnification: Filter

        /// Creates independent minification and magnification filtering.
        /// - Parameters:
        ///   - minification: Filter used while shrinking.
        ///   - magnification: Filter used while enlarging.
        public init(
            minification: Filter = .nearest,
            magnification: Filter = .nearest
        ) {
            self.minification = minification
            self.magnification = magnification
        }

        /// Nearest-neighbour filtering for both shrinking and enlarging.
        public static let nearest: Self = .init()
        /// Linear filtering for both shrinking and enlarging.
        public static let linear: Self = .init(
            minification: .linear,
            magnification: .linear
        )
    }

    /// A texture sampling filter.
    enum Filter: Hashable, Sendable {
        /// Selects the nearest texel without interpolation.
        case nearest
        /// Interpolates neighbouring texels linearly.
        case linear
    }

    /// Texture addressing along the sprite image's horizontal and vertical axes.
    struct Addressing: Hashable, Sendable {
        /// Addressing along the horizontal texture axis.
        public var horizontal: AddressMode
        /// Addressing along the vertical texture axis.
        public var vertical: AddressMode

        /// Creates independent horizontal and vertical addressing.
        /// - Parameters:
        ///   - horizontal: Behaviour outside the horizontal coordinate range.
        ///   - vertical: Behaviour outside the vertical coordinate range.
        public init(
            horizontal: AddressMode = .clampToEdge,
            vertical: AddressMode = .clampToEdge
        ) {
            self.horizontal = horizontal
            self.vertical = vertical
        }

        /// Clamps both axes to their edge texels.
        public static let clampToEdge: Self = .init()
        /// Repeats both texture axes.
        public static let `repeat`: Self = .init(
            horizontal: .repeat,
            vertical: .repeat
        )
        /// Repeats and mirrors both texture axes on alternate intervals.
        public static let mirrorRepeat: Self = .init(
            horizontal: .mirrorRepeat,
            vertical: .mirrorRepeat
        )
    }

    /// Behaviour for texture coordinates outside one axis's normal range.
    enum AddressMode: Hashable, Sendable {
        /// Samples the closest edge texel.
        case clampToEdge
        /// Wraps coordinates back to the opposite edge.
        case `repeat`
        /// Wraps coordinates while mirroring alternate repetitions.
        case mirrorRepeat
    }

    /// Fixed-function composition applied when the sprite is rendered.
    enum BlendMode: Hashable, Sendable {
        /// Source-over composition matching the texture asset's alpha processing.
        ///
        /// Premultiplied assets use premultiplied source-over; passthrough
        /// assets use straight-alpha source-over.
        case normal

        /// Replaces the destination with the sprite output.
        case replace
    }
}
