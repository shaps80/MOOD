import Metal
import PixlPlatform

extension PrimitiveTopology {
    var metalPrimitiveType: MTLPrimitiveType {
        switch self {
        case .point: .point
        case .line, .lineStrip: .line
        case .triangle, .triangleStrip: .triangle
        }
    }

    var metalPrimitiveTopology: MTLPrimitiveTopologyClass {
        switch self {
        case .point: .point
        case .line, .lineStrip: .line
        case .triangle, .triangleStrip: .triangle
        }
    }
}
