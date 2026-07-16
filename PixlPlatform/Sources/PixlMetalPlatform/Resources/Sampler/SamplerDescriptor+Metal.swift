import Metal
import PixlPlatform

extension SamplerDescriptor {
    var metalDescriptor: MTLSamplerDescriptor {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = minFilter.metalFilter
        descriptor.magFilter = magFilter.metalFilter
        descriptor.mipFilter = mipFilter.metalMipFilter
        descriptor.sAddressMode = addressModeU.metalAddressMode
        descriptor.tAddressMode = addressModeV.metalAddressMode
        descriptor.rAddressMode = addressModeW.metalAddressMode
        return descriptor
    }
}

private extension SamplerFilter {
    var metalFilter: MTLSamplerMinMagFilter {
        switch self {
        case .nearest: .nearest
        case .linear: .linear
        }
    }

    var metalMipFilter: MTLSamplerMipFilter {
        switch self {
        case .nearest: .nearest
        case .linear: .linear
        }
    }
}

private extension SamplerAddressMode {
    var metalAddressMode: MTLSamplerAddressMode {
        switch self {
        case .clampToEdge: .clampToEdge
        case .repeat: .repeat
        case .mirrorRepeat: .mirrorRepeat
        }
    }
}
