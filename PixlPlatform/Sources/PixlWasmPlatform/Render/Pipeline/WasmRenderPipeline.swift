import JavaScriptKit
import PixlPlatform

final class WasmRenderPipeline {
    private let device: JSObject
    private let descriptor: JSObject
    private var point: JSObject?
    private var line: JSObject?
    private var lineStrip: JSObject?
    private var triangle: JSObject?
    private var triangleStrip: JSObject?

    init(device: JSObject, descriptor: JSObject) {
        self.device = device
        self.descriptor = descriptor
    }

    func state(for topology: PrimitiveTopology) -> JSObject? {
        switch topology {
        case .point:
            if let point { return point }
            point = makeState(for: topology)
            return point
        case .line:
            if let line { return line }
            line = makeState(for: topology)
            return line
        case .lineStrip:
            if let lineStrip { return lineStrip }
            lineStrip = makeState(for: topology)
            return lineStrip
        case .triangle:
            if let triangle { return triangle }
            triangle = makeState(for: topology)
            return triangle
        case .triangleStrip:
            if let triangleStrip { return triangleStrip }
            triangleStrip = makeState(for: topology)
            return triangleStrip
        }
    }

    private func makeState(for topology: PrimitiveTopology) -> JSObject? {
        let primitive = object()
        primitive["topology"] = .string(topology.webGPUName)
        descriptor["primitive"] = .object(primitive)
        return device.createRenderPipeline!(descriptor).object
    }
}
