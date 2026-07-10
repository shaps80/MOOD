import Swift

public struct RenderTarget: Hashable, Sendable {
    public var texture: Texture
    public var mipLevel: Int
    public var arrayLayer: Int

    public init(texture: Texture, mipLevel: Int = 0, arrayLayer: Int = 0) {
        self.texture = texture
        self.mipLevel = mipLevel
        self.arrayLayer = arrayLayer
    }
}
