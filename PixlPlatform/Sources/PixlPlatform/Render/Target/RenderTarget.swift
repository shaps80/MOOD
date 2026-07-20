import Swift

/// One renderable texture subresource.
public struct RenderTarget: Hashable, Sendable {
    /// Texture containing the subresource.
    public var texture: Texture
    /// Zero-based mip level rendered into.
    public var mipLevel: Int
    /// Zero-based array layer rendered into.
    public var arrayLayer: Int

    /// Creates a render target for one texture subresource.
    /// - Parameters:
    ///   - texture: Texture created with render-attachment usage.
    ///   - mipLevel: Zero-based mip level.
    ///   - arrayLayer: Zero-based array or depth layer.
    public init(texture: Texture, mipLevel: Int = 0, arrayLayer: Int = 0) {
        self.texture = texture
        self.mipLevel = mipLevel
        self.arrayLayer = arrayLayer
    }
}
