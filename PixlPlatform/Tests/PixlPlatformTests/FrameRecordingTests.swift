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
        let sampledTexture = Texture(
            id: ResourceID(index: 4, generation: 1),
            descriptor: TextureDescriptor(
                size: TextureSize(width: 8, height: 8),
                format: .rgba8Unorm,
                usage: .sampled
            )
        )
        let sampler = Sampler(
            id: ResourceID(index: 5, generation: 1),
            descriptor: SamplerDescriptor()
        )
        let buffer = Buffer(
            id: ResourceID(index: 3, generation: 1),
            descriptor: BufferDescriptor(
                size: 256,
                usage: .vertex,
                memory: .gpuOnly
            )
        )
        let frame = Frame(passCapacity: 1, commandCapacity: 6, byteCapacity: 64)
        let pass = frame.beginRenderPass(
            RenderPassDescriptor(
                ColorAttachment(
                    target: RenderTarget(texture: texture),
                    loadAction: .clear(Color(0, 0, 0, 1))
                )
            )
        )

        #expect(pass.colorFormat == PixelFormat.bgra8Unorm)

        pass.setRenderPipeline(pipeline)
        pass.setVertexBuffer(buffer, offset: 32, index: 0)
        pass.setVertexBytes(of: SIMD4<Float>(1, 2, 3, 4), index: 1)
        pass.setFragmentTexture(sampledTexture, index: 0)
        pass.setFragmentSampler(sampler, index: 0)
        pass.drawPrimitives(
            .triangleStrip,
            vertexStart: 4,
            vertexCount: 6,
            instanceCount: 2,
            baseInstance: 3
        )

        #expect(frame.passCount == 1)
        #expect(frame.commandCount == 6)
        #expect(frame.byteCount == 16)

        guard case .render(let recordedPass) = frame[0] else {
            Issue.record("Expected a render pass")
            return
        }
        #expect(recordedPass.commandStart == 0)
        #expect(recordedPass.commandCount == 6)

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

        guard case .setVertexBytes(let byteOffset, let byteCount, let byteIndex) = frame[command: 2] else {
            Issue.record("Expected a vertex-bytes command")
            return
        }
        #expect(byteOffset == 0)
        #expect(byteCount == 16)
        #expect(byteIndex == 1)
        frame.withBytes(offset: byteOffset, count: byteCount) {
            #expect($0.load(as: SIMD4<Float>.self) == SIMD4<Float>(1, 2, 3, 4))
        }

        guard case .setFragmentTexture(
            let textureID,
            let textureIndex
        ) = frame[command: 3] else {
            Issue.record("Expected a fragment-texture command")
            return
        }
        #expect(textureID == sampledTexture.id)
        #expect(textureIndex == 0)

        guard case .setFragmentSampler(
            let samplerID,
            let samplerIndex
        ) = frame[command: 4] else {
            Issue.record("Expected a fragment-sampler command")
            return
        }
        #expect(samplerID == sampler.id)
        #expect(samplerIndex == 0)

        guard case .drawPrimitives(
            let topology,
            let vertexStart,
            let vertexCount,
            let instanceCount,
            let baseInstance
        ) = frame[command: 5] else {
            Issue.record("Expected a primitive-draw command")
            return
        }
        #expect(topology == .triangleStrip)
        #expect(vertexStart == 4)
        #expect(vertexCount == 6)
        #expect(instanceCount == 2)
        #expect(baseInstance == 3)
    }

    @Test
    func recordsIndexedDrawWithItsBufferAndOffsets() {
        let texture = Texture(
            id: ResourceID(index: 1, generation: 1),
            descriptor: TextureDescriptor(
                size: TextureSize(width: 16, height: 16),
                format: .bgra8Unorm,
                usage: .renderAttachment
            )
        )
        let pipeline = RenderPipeline(id: ResourceID(index: 2, generation: 1))
        let indexBuffer = Buffer(
            id: ResourceID(index: 3, generation: 1),
            descriptor: BufferDescriptor(
                size: 24,
                usage: .index,
                memory: .gpuOnly
            )
        )
        let frame = Frame(passCapacity: 1, commandCapacity: 2, byteCapacity: 1)
        let pass = frame.beginRenderPass(
            RenderPassDescriptor(
                ColorAttachment(
                    target: RenderTarget(texture: texture),
                    loadAction: .clear(Color(0, 0, 0, 1))
                )
            )
        )

        pass.setRenderPipeline(pipeline)
        pass.drawIndexedPrimitives(
            .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 4,
            instanceCount: 2,
            baseVertex: -3,
            baseInstance: 5
        )

        guard case .drawIndexedPrimitives(
            let topology,
            let indexType,
            let bufferID,
            let offset,
            let count,
            let instances,
            let baseVertex,
            let baseInstance
        ) = frame[command: 1] else {
            Issue.record("Expected an indexed draw command")
            return
        }
        #expect(topology == .triangle)
        #expect(indexType == .uint16)
        #expect(bufferID == indexBuffer.id)
        #expect(offset == 4)
        #expect(count == 6)
        #expect(instances == 2)
        #expect(baseVertex == -3)
        #expect(baseInstance == 5)
    }
}
