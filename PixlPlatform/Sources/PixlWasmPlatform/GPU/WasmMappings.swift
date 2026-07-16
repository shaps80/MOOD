import JavaScriptKit
import PixlPlatform

extension PixelFormat {
    var webGPUName: String {
        switch self {
        case .rgba8Unorm: "rgba8unorm"
        case .bgra8Unorm: "bgra8unorm"
        case .depth32Float: "depth32float"
        }
    }
}

extension PrimitiveTopology {
    var webGPUName: String {
        switch self {
        case .point: "point-list"
        case .line: "line-list"
        case .lineStrip: "line-strip"
        case .triangle: "triangle-list"
        case .triangleStrip: "triangle-strip"
        }
    }
}

extension VertexFormat {
    var webGPUName: String {
        switch self {
        case .uint8x2: "uint8x2"; case .uint8x4: "uint8x4"
        case .sint8x2: "sint8x2"; case .sint8x4: "sint8x4"
        case .unorm8x2: "unorm8x2"; case .unorm8x4: "unorm8x4"
        case .snorm8x2: "snorm8x2"; case .snorm8x4: "snorm8x4"
        case .uint16x2: "uint16x2"; case .uint16x4: "uint16x4"
        case .sint16x2: "sint16x2"; case .sint16x4: "sint16x4"
        case .unorm16x2: "unorm16x2"; case .unorm16x4: "unorm16x4"
        case .snorm16x2: "snorm16x2"; case .snorm16x4: "snorm16x4"
        case .float16x2: "float16x2"; case .float16x4: "float16x4"
        case .float32: "float32"; case .float32x2: "float32x2"
        case .float32x3: "float32x3"; case .float32x4: "float32x4"
        case .uint32: "uint32"; case .uint32x2: "uint32x2"
        case .uint32x3: "uint32x3"; case .uint32x4: "uint32x4"
        case .sint32: "sint32"; case .sint32x2: "sint32x2"
        case .sint32x3: "sint32x3"; case .sint32x4: "sint32x4"
        }
    }
}

extension SamplerFilter {
    var webGPUName: String {
        switch self {
        case .nearest: "nearest"
        case .linear: "linear"
        }
    }
}

extension SamplerAddressMode {
    var webGPUName: String {
        switch self {
        case .clampToEdge: "clamp-to-edge"
        case .repeat: "repeat"
        case .mirrorRepeat: "mirror-repeat"
        }
    }
}

func object() -> JSObject { JSObject.global.Object.function!.new() }
func array() -> JSArray { JSArray(unsafelyWrapping: JSObject.global.Array.function!.new()) }
