import Metal
import PixlPlatform

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

extension MTLPixelFormat {
    var pixlPixelFormat: PixelFormat? {
        switch self {
        case .rgba8Unorm:
            return .rgba8Unorm
        case .bgra8Unorm:
            return .bgra8Unorm
        case .depth32Float:
            return .depth32Float
        default:
            return nil
        }
    }
}
