import PixlGraphics

/// A mutable, value-semantic description of one sprite.
public struct Sprite {
    public var region: TextureRegion
    public var material: Material
    public var layer: RenderLayer
    public var order: UInt32
    public var isFlipped: Bool

    public var asset: TextureAsset {
        region.asset
    }

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
        public var filtering: Filtering
        public var addressing: Addressing
        public var blendMode: BlendMode

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
        public var minification: Filter
        public var magnification: Filter

        public init(
            minification: Filter = .nearest,
            magnification: Filter = .nearest
        ) {
            self.minification = minification
            self.magnification = magnification
        }

        public static let nearest: Self = .init()
        public static let linear: Self = .init(
            minification: .linear,
            magnification: .linear
        )
    }

    enum Filter: Hashable, Sendable {
        case nearest
        case linear
    }

    /// Texture addressing along the sprite image's horizontal and vertical axes.
    struct Addressing: Hashable, Sendable {
        public var horizontal: AddressMode
        public var vertical: AddressMode

        public init(
            horizontal: AddressMode = .clampToEdge,
            vertical: AddressMode = .clampToEdge
        ) {
            self.horizontal = horizontal
            self.vertical = vertical
        }

        public static let clampToEdge: Self = .init()
        public static let `repeat`: Self = .init(
            horizontal: .repeat,
            vertical: .repeat
        )
        public static let mirrorRepeat: Self = .init(
            horizontal: .mirrorRepeat,
            vertical: .mirrorRepeat
        )
    }

    enum AddressMode: Hashable, Sendable {
        case clampToEdge
        case `repeat`
        case mirrorRepeat
    }

    /// Fixed-function composition applied when the sprite is rendered.
    enum BlendMode: Hashable, Sendable {
        /// Straight-alpha source-over composition.
        case normal

        /// Replaces the destination with the sprite output.
        case replace
    }
}
