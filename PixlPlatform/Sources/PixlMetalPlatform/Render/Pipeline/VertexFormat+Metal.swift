import Metal
import PixlPlatform

extension VertexFormat {
    var metalVertexFormat: MTLVertexFormat {
        switch self {
        case .uint8x2: .uchar2
        case .uint8x4: .uchar4
        case .sint8x2: .char2
        case .sint8x4: .char4
        case .unorm8x2: .uchar2Normalized
        case .unorm8x4: .uchar4Normalized
        case .snorm8x2: .char2Normalized
        case .snorm8x4: .char4Normalized
        case .uint16x2: .ushort2
        case .uint16x4: .ushort4
        case .sint16x2: .short2
        case .sint16x4: .short4
        case .unorm16x2: .ushort2Normalized
        case .unorm16x4: .ushort4Normalized
        case .snorm16x2: .short2Normalized
        case .snorm16x4: .short4Normalized
        case .float16x2: .half2
        case .float16x4: .half4
        case .float32: .float
        case .float32x2: .float2
        case .float32x3: .float3
        case .float32x4: .float4
        case .uint32: .uint
        case .uint32x2: .uint2
        case .uint32x3: .uint3
        case .uint32x4: .uint4
        case .sint32: .int
        case .sint32x2: .int2
        case .sint32x3: .int3
        case .sint32x4: .int4
        }
    }
}

extension VertexStepMode {
    var metalStepFunction: MTLVertexStepFunction {
        switch self {
        case .perVertex: .perVertex
        case .perInstance: .perInstance
        }
    }
}
