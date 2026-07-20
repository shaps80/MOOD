import Swift

/// Integer texture extent and array/depth count.
public struct TextureSize: Hashable, Sendable {
    /// Width in texels.
    public var width: Int
    /// Height in texels.
    public var height: Int
    /// Depth for 3D textures or layer count for arrays.
    public var depthOrArrayLayers: Int

    /// Creates a texture extent.
    /// - Parameters:
    ///   - width: Width in texels.
    ///   - height: Height in texels.
    ///   - depthOrArrayLayers: Depth or array-layer count.
    public init(
        width: Int,
        height: Int,
        depthOrArrayLayers: Int = 1
    ) {
        self.width = width
        self.height = height
        self.depthOrArrayLayers = depthOrArrayLayers
    }
}
