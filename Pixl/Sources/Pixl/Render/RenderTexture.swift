import PixlGraphics
import PixlPlatform

/// Context-owned colour texture that can receive rendering and be sampled by sprites.
///
/// The creating context owns the underlying GPU resource for its complete
/// lifetime. Use ``texture`` to create regions and sprites; Pixl resolves the
/// render destination when this value is passed to `GameContext.render`.
public struct RenderTexture: Hashable, Sendable {
    /// Logical sampled-texture value used to create regions and sprites.
    public let texture: TextureAsset
    /// Texel format used by render pipelines targeting this texture.
    public let format: PixelFormat

    /// Pixel dimensions of the texture.
    public var size: SIMD2<Int> { texture.size }
    /// Alpha representation expected when sampling the rendered contents.
    public var alpha: TextureAlpha { texture.alpha }

    /// Creates a context-owned renderable and sampleable texture.
    /// - Parameters:
    ///   - size: Positive pixel dimensions.
    ///   - format: Colour format. Defaults to RGBA8 normalized colour.
    ///   - alpha: Alpha representation produced by rendering. Defaults to
    ///     premultiplied alpha for normal sprite composition.
    ///   - context: Context whose GPU resources own the texture.
    /// - Throws: ``AssetError/unavailable`` when the context has no texture
    ///   storage, or ``AssetError/textureCreation(_:)`` when `size`, `format`,
    ///   or GPU creation is invalid.
    public init(
        size: SIMD2<Int>,
        format: PixelFormat = .rgba8Unorm,
        alpha: TextureAlpha = .premultiplied,
        context: GameContext
    ) throws(AssetError) {
        guard size.x > 0, size.y > 0 else {
            throw .textureCreation(
                .invalidTextureDescriptor(
                    .init(
                        size: .init(width: size.x, height: size.y),
                        format: format,
                        usage: [.renderAttachment, .sampled]
                    )
                )
            )
        }
        guard format == .rgba8Unorm || format == .bgra8Unorm else {
            throw .textureCreation(.unsupportedFormat(format))
        }
        let descriptor = TextureDescriptor(
            size: .init(width: size.x, height: size.y),
            format: format,
            usage: [.renderAttachment, .sampled]
        )
        let resource: Texture
        do {
            resource = try context.platform.device.makeTexture(descriptor)
        } catch {
            throw .textureCreation(error)
        }
        guard let resources = context.assets.textureResources else {
            context.platform.device.destroy(resource)
            throw .unavailable
        }
        let identity = resources.insert(resource)
        texture = TextureAsset(
            identity: identity.rawValue,
            size: size,
            alpha: alpha
        )
        self.format = format
    }
}
