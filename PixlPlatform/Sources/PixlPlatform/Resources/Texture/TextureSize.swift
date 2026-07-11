import Swift

public struct TextureSize: Hashable, Sendable {
    public var width: Int
    public var height: Int
    public var depthOrArrayLayers: Int

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
