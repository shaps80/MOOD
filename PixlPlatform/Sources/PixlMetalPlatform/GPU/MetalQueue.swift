import Metal
import QuartzCore
import PixlPlatform

final class MetalQueue: Queue {
    private let queue: MTLCommandQueue
    private let buffers: ResourcePool<MTLBuffer>
    private let pipelines: ResourcePool<MetalRenderPipeline>
    private let samplers: ResourcePool<MTLSamplerState>
    private let textures: ResourcePool<MTLTexture>

    init(
        queue: MTLCommandQueue,
        buffers: ResourcePool<MTLBuffer>,
        pipelines: ResourcePool<MetalRenderPipeline>,
        samplers: ResourcePool<MTLSamplerState>,
        textures: ResourcePool<MTLTexture>
    ) {
        self.queue = queue
        self.buffers = buffers
        self.pipelines = pipelines
        self.samplers = samplers
        self.textures = textures
    }

    func submit(_ frame: borrowing Frame) throws(QueueError) {
        try submit(frame, presenting: nil)
    }

    func submit(
        _ frame: borrowing Frame,
        presenting drawable: (any CAMetalDrawable)?
    ) throws(QueueError) {
        guard let commandBuffer = queue.makeCommandBuffer() else {
            throw QueueError.commandBufferCreationFailed
        }

        var index: UInt32 = 0

        while index < frame.passCount {
            let pass = frame[index]

            switch pass {
            case .render(let renderPass):
                try encode(renderPass, from: frame, into: commandBuffer)
            }

            index += 1
        }

        if let drawable {
            commandBuffer.present(drawable)
        }

        commandBuffer.commit()
    }

    private func encode(
        _ pass: RecordedRenderPass,
        from frame: borrowing Frame,
        into commandBuffer: MTLCommandBuffer
    ) throws(QueueError) {
        let attachment = pass.descriptor.colorAttachment
        let target = attachment.target
        let descriptor = MTLRenderPassDescriptor()

        guard textures.withValue(for: target.texture.id, { texture in
            descriptor.colorAttachments[0].texture = texture.pointee
        }) != nil else {
            throw QueueError.invalidResource
        }

        descriptor.colorAttachments[0].level = target.mipLevel
        descriptor.colorAttachments[0].slice = target.arrayLayer
        descriptor.colorAttachments[0].loadAction = attachment.loadAction.metalLoadAction
        descriptor.colorAttachments[0].storeAction = attachment.storeAction.metalStoreAction

        if case .clear(let color) = attachment.loadAction {
            descriptor.colorAttachments[0].clearColor = color.metalClearColor
        }

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            throw QueueError.encoderCreationFailed
        }

        var commandIndex = pass.commandStart
        let commandEnd = pass.commandStart + pass.commandCount
        while commandIndex < commandEnd {
            switch frame[command: commandIndex] {
            case .setRenderPipeline(let pipeline):
                guard pipelines.withValue(for: pipeline, { pipeline in
                    encoder.setRenderPipelineState(pipeline.pointee.state)
                }) != nil else {
                    throw QueueError.invalidResource
                }

            case .setVertexBuffer(let buffer, let offset, let index):
                guard let metalOffset = Int(exactly: offset),
                      buffers.withValue(for: buffer, { buffer in
                          encoder.setVertexBuffer(
                              buffer.pointee,
                              offset: metalOffset,
                              index: Int(index)
                          )
                      }) != nil
                else {
                    throw QueueError.invalidResource
                }

            case .setVertexBytes(let offset, let count, let index):
                frame.withBytes(offset: offset, count: count) { bytes in
                    encoder.setVertexBytes(
                        bytes.baseAddress!,
                        length: bytes.count,
                        index: Int(index)
                    )
                }

            case .setFragmentTexture(let texture, let index):
                guard textures.withValue(for: texture, { texture in
                    encoder.setFragmentTexture(
                        texture.pointee,
                        index: Int(index)
                    )
                }) != nil else {
                    throw QueueError.invalidResource
                }

            case .setFragmentSampler(let sampler, let index):
                guard samplers.withValue(for: sampler, { sampler in
                    encoder.setFragmentSamplerState(
                        sampler.pointee,
                        index: Int(index)
                    )
                }) != nil else {
                    throw QueueError.invalidResource
                }

            case .drawPrimitives(
                let topology,
                let vertexStart,
                let vertexCount,
                let instanceCount,
                let baseInstance
            ):
                encoder.drawPrimitives(
                    type: topology.metalPrimitiveType,
                    vertexStart: Int(vertexStart),
                    vertexCount: Int(vertexCount),
                    instanceCount: Int(instanceCount),
                    baseInstance: Int(baseInstance)
                )

            case .drawIndexedPrimitives(
                let topology,
                let indexType,
                let indexBuffer,
                let indexBufferOffset,
                let indexCount,
                let instanceCount,
                let baseVertex,
                let baseInstance
            ):
                guard let metalOffset = Int(exactly: indexBufferOffset),
                      buffers.withValue(for: indexBuffer, { buffer in
                          encoder.drawIndexedPrimitives(
                              type: topology.metalPrimitiveType,
                              indexCount: Int(indexCount),
                              indexType: indexType.metalIndexType,
                              indexBuffer: buffer.pointee,
                              indexBufferOffset: metalOffset,
                              instanceCount: Int(instanceCount),
                              baseVertex: Int(baseVertex),
                              baseInstance: Int(baseInstance)
                          )
                      }) != nil
                else {
                    throw QueueError.invalidResource
                }
            }
            commandIndex += 1
        }

        encoder.endEncoding()
    }
}
