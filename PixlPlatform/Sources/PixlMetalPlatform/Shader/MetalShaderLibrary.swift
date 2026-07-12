import Metal
import PixlPlatform

final class MetalShaderLibrary: ShaderLibrary {
    let library: MTLLibrary

    init(library: MTLLibrary) {
        self.library = library
    }
}
