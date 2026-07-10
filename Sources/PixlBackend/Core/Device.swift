import Swift

public protocol Device {
    func makeTexture(_ descriptor: TextureDescriptor) throws -> Texture
}
