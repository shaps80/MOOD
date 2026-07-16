import JavaScriptKit
import PixlPlatform

final class WasmQueue: Queue {
    private let device: JSObject
    private let buffers: ResourcePool<JSObject>
    private let pipelines: ResourcePool<WasmRenderPipeline>
    private let textures: ResourcePool<JSObject>
    private let immediateBuffer: JSObject
    private let immediateBindGroup: JSObject
    private let immediateAlignment: UInt32
    private let immediateOffsets: JSArray

    init(
        device: JSObject,
        buffers: ResourcePool<JSObject>,
        pipelines: ResourcePool<WasmRenderPipeline>,
        textures: ResourcePool<JSObject>,
        immediateBuffer: JSObject,
        immediateBindGroup: JSObject,
        immediateAlignment: UInt32
    ) {
        self.device = device
        self.buffers = buffers
        self.pipelines = pipelines
        self.textures = textures
        self.immediateBuffer = immediateBuffer
        self.immediateBindGroup = immediateBindGroup
        self.immediateAlignment = immediateAlignment
        immediateOffsets = array()
        _ = immediateOffsets.jsObject.push!(0)
    }

    func submit(_ frame: Frame) throws(QueueError) {
        guard let commandEncoder = device.createCommandEncoder!().object else {
            throw .commandBufferCreationFailed
        }
        var immediateOffset: UInt32 = 0
        var index: UInt32 = 0
        while index < frame.passCount {
            switch frame[index] {
            case .render(let pass):
                try encode(
                    pass,
                    from: frame,
                    into: commandEncoder,
                    immediateOffset: &immediateOffset
                )
            }
            index += 1
        }
        guard let commands = commandEncoder.finish!().object else {
            throw .commandBufferCreationFailed
        }
        let list = array()
        _ = list.jsObject.push!(commands)
        _ = device.queue.submit(list.jsObject)
    }

    private func encode(
        _ pass: RecordedRenderPass,
        from frame: borrowing Frame,
        into commandEncoder: JSObject,
        immediateOffset: inout UInt32
    ) throws(QueueError) {
        let attachment = pass.descriptor.colorAttachment
        var view: JSObject?
        _ = textures.withValue(for: attachment.target.texture.id) { texture in
            view = texture.pointee.createView!().object
        }
        guard let view else { throw .invalidResource }

        let color = object()
        color["view"] = .object(view)
        switch attachment.loadAction {
        case .load:
            color["loadOp"] = .string("load")
        case .discard:
            color["loadOp"] = .string("clear")
        case .clear(let value):
            color["loadOp"] = .string("clear")
            let clear = object()
            clear["r"] = .number(Double(value[0]))
            clear["g"] = .number(Double(value[1]))
            clear["b"] = .number(Double(value[2]))
            clear["a"] = .number(Double(value[3]))
            color["clearValue"] = .object(clear)
        }
        color["storeOp"] = .string(attachment.storeAction == .store ? "store" : "discard")

        let colors = array()
        _ = colors.jsObject.push!(color)
        let descriptor = object()
        descriptor["colorAttachments"] = .object(colors.jsObject)
        guard let encoder = commandEncoder.beginRenderPass!(descriptor).object else {
            throw .encoderCreationFailed
        }

        var currentPipeline: ResourceID?
        var currentImmediateOffset: UInt32?
        var commandIndex = pass.commandStart
        let commandEnd = pass.commandStart + pass.commandCount
        while commandIndex < commandEnd {
            switch frame[command: commandIndex] {
            case .setRenderPipeline(let pipeline):
                currentPipeline = pipeline

            case .setVertexBuffer(let buffer, let offset, let index):
                guard buffers.withValue(for: buffer, { native in
                    _ = encoder.setVertexBuffer!(
                        Double(index),
                        native.pointee,
                        Double(offset)
                    )
                }) != nil else {
                    throw .invalidResource
                }

            case .setVertexBytes(let offset, let count, let index):
                precondition(index == 1, "Current generated WGSL maps vertex bytes at index 1")
                immediateOffset = aligned(immediateOffset, to: immediateAlignment)
                frame.withBytes(offset: offset, count: count) { bytes in
                    let source = JSUint8Array(buffer: bytes.bindMemory(to: UInt8.self))
                    _ = device.queue.writeBuffer(
                        immediateBuffer,
                        Double(immediateOffset),
                        source.jsObject
                    )
                }
                currentImmediateOffset = immediateOffset
                immediateOffset += count

            case .setFragmentTexture, .setFragmentSampler:
                throw .invalidResource

            case .drawPrimitives(
                let topology,
                let vertexStart,
                let vertexCount,
                let instanceCount,
                let baseInstance
            ):
                guard let currentPipeline,
                      pipelines.withValue(for: currentPipeline, { pipeline in
                          guard let state = pipeline.pointee.state(for: topology) else {
                              return false
                          }
                          _ = encoder.setPipeline!(state)
                          return true
                      }) == true
                else {
                    throw .invalidResource
                }

                if let currentImmediateOffset {
                    immediateOffsets.jsObject["0"] = .number(Double(currentImmediateOffset))
                    _ = encoder.setBindGroup!(0, immediateBindGroup, immediateOffsets.jsObject)
                }

                _ = encoder.draw!(
                    Double(vertexCount),
                    Double(instanceCount),
                    Double(vertexStart),
                    Double(baseInstance)
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
                guard let currentPipeline,
                      pipelines.withValue(for: currentPipeline, { pipeline in
                          guard let state = pipeline.pointee.state(for: topology) else {
                              return false
                          }
                          _ = encoder.setPipeline!(state)
                          return true
                      }) == true,
                      buffers.withValue(for: indexBuffer, { native in
                          _ = encoder.setIndexBuffer!(
                              native.pointee,
                              indexType.wasmIndexFormat,
                              Double(indexBufferOffset)
                          )
                      }) != nil
                else {
                    throw .invalidResource
                }

                if let currentImmediateOffset {
                    immediateOffsets.jsObject["0"] = .number(Double(currentImmediateOffset))
                    _ = encoder.setBindGroup!(0, immediateBindGroup, immediateOffsets.jsObject)
                }

                _ = encoder.drawIndexed!(
                    Double(indexCount),
                    Double(instanceCount),
                    0,
                    Double(baseVertex),
                    Double(baseInstance)
                )
            }
            commandIndex += 1
        }
        _ = encoder.end!()
    }

    private func aligned(_ value: UInt32, to alignment: UInt32) -> UInt32 {
        let remainder = value % alignment
        return remainder == 0 ? value : value + alignment - remainder
    }
}

private extension IndexType {
    var wasmIndexFormat: String {
        switch self {
        case .uint16: "uint16"
        case .uint32: "uint32"
        }
    }
}
