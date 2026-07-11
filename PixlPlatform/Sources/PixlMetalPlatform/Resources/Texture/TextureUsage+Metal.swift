import Metal
import PixlPlatform

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
