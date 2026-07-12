import Metal
import PixlPlatform

extension PrimitiveTopology {
    var metalPrimitiveType: MTLPrimitiveType {
        switch self {
        case .point: .point
        case .line: .line
        case .lineStrip: .lineStrip
        case .triangle: .triangle
        case .triangleStrip: .triangleStrip
        }
    }
}

extension IndexType {
    var metalIndexType: MTLIndexType {
        switch self {
        case .uint16: .uint16
        case .uint32: .uint32
        }
    }
}
