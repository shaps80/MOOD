import PixlGraphics

/// Mutable, value-semantic texture-backed renderable content.
public struct Sprite: Renderable, Sendable {
    /// Texture paint displayed by the sprite.
    public var paint: Paint.Texture
    /// Per-instance colour multiplied with the sampled texture.
    public var modulation: Color

    public typealias Transform = Transform2D
    public typealias Bounds = Rect

    /// Texture region displayed by the sprite.
    public var region: TextureRegion {
        get { paint.region }
        set { paint.region = newValue }
    }

    /// Sampling used to read the texture region.
    public var sampling: TextureSampling {
        get { paint.sampling }
        set { paint.sampling = newValue }
    }

    /// Texture asset containing `region`.
    public var asset: TextureAsset {
        region.asset
    }

    /// Size of the displayed texture region in sprite units.
    public var size: Vec2 {
        region.source.size
    }

    /// Creates sprite content from a texture region.
    ///
    /// ```swift
    /// var sprite = Sprite(region: sheet.region(column: 0, row: 0))
    /// ```
    ///
    /// - Parameters:
    ///   - region: Texture region displayed by the sprite.
    ///   - sampling: Filtering and addressing used to read the region.
    ///   - modulation: Per-instance colour multiplied with sampled texels.
    public init(
        region: TextureRegion,
        sampling: TextureSampling = .init(),
        modulation: Color = .white
    ) {
        paint = .init(region: region, sampling: sampling)
        self.modulation = modulation
    }

    package var modulationMode: ModulationMode {
        get { _modulationMode }
        set { _modulationMode = newValue }
    }

    package enum ModulationMode: UInt32, Sendable {
        case multiply
        case alphaMask
    }

    private var _modulationMode: ModulationMode = .multiply
}
