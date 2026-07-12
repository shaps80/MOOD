import Metal
import QuartzCore
import PixlPlatform

final class MetalQueue: Queue {
    private let queue: MTLCommandQueue
    private let buffers: ResourcePool<MTLBuffer>
    private let pipelines: ResourcePool<MetalRenderPipeline>
    private let textures: ResourcePool<MTLTexture>

    init(
        queue: MTLCommandQueue,
        buffers: ResourcePool<MTLBuffer>,
        pipelines: ResourcePool<MetalRenderPipeline>,
        textures: ResourcePool<MTLTexture>
    ) {
        self.queue = queue
        self.buffers = buffers
        self.pipelines = pipelines
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
            case .compute:
                throw QueueError.unsupportedPass
            }

            index += 1
        }

        if let drawable {
            commandBuffer.present(drawable)
        }

        commandBuffer.commit()
    }

    private func encode(
        _ pass: RenderPass,
        from frame: borrowing Frame,
        into commandBuffer: MTLCommandBuffer
    ) throws(QueueError) {
        let attachment = pass.colorAttachment
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

        var drawIndex = pass.drawStart
        let drawEnd = pass.drawStart + pass.drawCount
        while drawIndex < drawEnd {
            let draw = frame[draw: drawIndex]

            guard buffers.withValue(for: draw.vertexBuffer.id, { buffer in
                encoder.setVertexBuffer(buffer.pointee, offset: 0, index: 0)
                return true
            }) == true else {
                throw QueueError.invalidResource
            }
            guard pipelines.withValue(for: draw.pipeline.id, { pipeline in
                encoder.setRenderPipelineState(pipeline.pointee.state)
                encoder.drawPrimitives(
                    type: pipeline.pointee.topology,
                    vertexStart: 0,
                    vertexCount: Int(draw.vertexCount)
                )
                return true
            }) == true else {
                throw QueueError.invalidResource
            }
            drawIndex += 1
        }

        encoder.endEncoding()
    }
}
