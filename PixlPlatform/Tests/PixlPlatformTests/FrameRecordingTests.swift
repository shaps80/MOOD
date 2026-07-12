import Testing
@testable import PixlPlatform

@Suite("Frame recording")
struct FrameRecordingTests {
    @Test
    func recordsMetalShapedRenderCommandsContiguously() {
        let texture = Texture(
            id: ResourceID(index: 1, generation: 1),
            descriptor: TextureDescriptor(
                size: TextureSize(width: 16, height: 16),
                format: .bgra8Unorm,
                usage: .renderAttachment
            )
        )
        let pipeline = RenderPipeline(id: ResourceID(index: 2, generation: 1))
        let buffer = Buffer(
            id: ResourceID(index: 3, generation: 1),
            descriptor: BufferDescriptor(
                size: 256,
                usage: .vertex,
                memory: .gpuOnly
            )
        )
        let frame = Frame(passCapacity: 1, commandCapacity: 3)
        let pass = frame.beginRenderPass(
            RenderPassDescriptor(
                ColorAttachment(
                    target: RenderTarget(texture: texture),
                    loadAction: .clear(.black)
                )
            )
        )

        pass.setRenderPipeline(pipeline)
        pass.setVertexBuffer(buffer, offset: 32, index: 0)
        pass.drawPrimitives(
            .triangleStrip,
            vertexStart: 4,
            vertexCount: 6,
            instanceCount: 2,
            baseInstance: 3
        )

        #expect(frame.passCount == 1)
        #expect(frame.commandCount == 3)

        guard case .render(let recordedPass) = frame[0] else {
            Issue.record("Expected a render pass")
            return
        }
        #expect(recordedPass.commandStart == 0)
        #expect(recordedPass.commandCount == 3)

        guard case .setRenderPipeline(let pipelineID) = frame[command: 0] else {
            Issue.record("Expected a pipeline command")
            return
        }
        #expect(pipelineID == pipeline.id)

        guard case .setVertexBuffer(let bufferID, let offset, let index) = frame[command: 1] else {
            Issue.record("Expected a vertex-buffer command")
            return
        }
        #expect(bufferID == buffer.id)
        #expect(offset == 32)
        #expect(index == 0)

        guard case .drawPrimitives(
            let topology,
            let vertexStart,
            let vertexCount,
            let instanceCount,
            let baseInstance
        ) = frame[command: 2] else {
            Issue.record("Expected a primitive-draw command")
            return
        }
        #expect(topology == .triangleStrip)
        #expect(vertexStart == 4)
        #expect(vertexCount == 6)
        #expect(instanceCount == 2)
        #expect(baseInstance == 3)
    }
}
