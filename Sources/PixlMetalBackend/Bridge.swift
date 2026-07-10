import Metal
import PixlBackend

extension PixelFormat {
    var metalPixelFormat: MTLPixelFormat {
        switch self {
        case .rgba8Unorm:
            return .rgba8Unorm
        case .bgra8Unorm:
            return .bgra8Unorm
        case .depth32Float:
            return .depth32Float
        }
    }
}

extension TextureUsage {
    var metalUsage: MTLTextureUsage {
        var usage: MTLTextureUsage = []

        if contains(.sampled) {
            usage.insert(.shaderRead)
        }

        if contains(.renderAttachment) {
            usage.insert(.renderTarget)
        }

        if contains(.storage) {
            usage.insert([.shaderRead, .shaderWrite])
        }

        return usage
    }
}

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
        return metalDescriptor
    }
}
