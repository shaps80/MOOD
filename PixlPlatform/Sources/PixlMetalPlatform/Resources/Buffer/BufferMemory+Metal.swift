import Metal
import PixlPlatform

extension BufferMemory {
    var metalResourceOptions: MTLResourceOptions {
        switch self {
        case .gpuOnly: .storageModePrivate
        case .cpuVisible, .gpuToCPU: .storageModeShared
        }
    }
}
