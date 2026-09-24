import Metal

/// A bounded, immutable command cache. Changed draw counts replace the command;
/// in-flight command buffers retain their previous ICB until execution finishes.
final class ReusableDraw {
    private let device: any MTLDevice
    let isSupported: Bool
    private var cached: (primitive: MTLPrimitiveType, vertices: Int, instances: Int,
                         buffer: any MTLIndirectCommandBuffer)?

    init(device: any MTLDevice) {
        self.device = device
        self.isSupported = device.supportsFamily(.apple3) || device.supportsFamily(.mac2)
    }

    func command(primitive: MTLPrimitiveType, vertices: Int,
                 instances: Int) -> (any MTLIndirectCommandBuffer)? {
        guard isSupported, vertices > 0, instances > 0 else { return nil }
        if let cached, cached.primitive == primitive,
           cached.vertices == vertices, cached.instances == instances {
            return cached.buffer
        }
        let descriptor = MTLIndirectCommandBufferDescriptor()
        descriptor.commandTypes = .draw
        descriptor.inheritPipelineState = true
        descriptor.inheritBuffers = true
        descriptor.maxVertexBufferBindCount = 0
        descriptor.maxFragmentBufferBindCount = 0
        guard let buffer = device.makeIndirectCommandBuffer(
            descriptor: descriptor, maxCommandCount: 1, options: []
        ) else { return nil }
        buffer.label = "Reusable Draw"
        buffer.indirectRenderCommandAt(0).drawPrimitives(
            primitive, vertexStart: 0, vertexCount: vertices,
            instanceCount: instances, baseInstance: 0
        )
        cached = (primitive, vertices, instances, buffer)
        return buffer
    }
}
