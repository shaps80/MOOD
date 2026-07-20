import Metal
import PixlPlatform

extension TextureDescriptor {
    var metalDescriptor: MTLTextureDescriptor {
        let metalDescriptor = MTLTextureDescriptor()
        metalDescriptor.width = size.width
        metalDescriptor.height = size.height
        metalDescriptor.depth = 1
        metalDescriptor.arrayLength = size.depthOrArrayLayers
        metalDescriptor.pixelFormat = format.metalPixelFormat
        metalDescriptor.usage = usage.metalUsage
        metalDescriptor.sampleCount = sampleCount
        metalDescriptor.storageMode = .private
        return metalDescriptor
    }
}
