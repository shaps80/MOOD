import JavaScriptKit
import PixlPlatform

final class WasmQueue: Queue {
    private let device: JSObject
    private let buffers: ResourcePool<JSObject>
    private let pipelines: ResourcePool<JSObject>
    private let textures: ResourcePool<JSObject>

    init(device: JSObject, buffers: ResourcePool<JSObject>, pipelines: ResourcePool<JSObject>, textures: ResourcePool<JSObject>) {
        self.device = device; self.buffers = buffers; self.pipelines = pipelines; self.textures = textures
    }

    func submit(_ frame: Frame) throws(QueueError) {
        guard let commandEncoder = device.createCommandEncoder!().object else { throw .commandBufferCreationFailed }
        var index: UInt32 = 0
        while index < frame.passCount {
            switch frame[index] {
            case .render(let pass): try encode(pass, from: frame, into: commandEncoder)
            case .compute: throw .unsupportedPass
            }
            index += 1
        }
        guard let commands = commandEncoder.finish!().object else { throw .commandBufferCreationFailed }
        let list = array(); _ = list.jsObject.push!(commands); _ = device.queue.submit(list.jsObject)
    }

    private func encode(_ pass: RenderPass, from frame: borrowing Frame, into commandEncoder: JSObject) throws(QueueError) {
        let attachment = pass.colorAttachment
        var view: JSObject?
        _ = textures.withValue(for: attachment.target.texture.id) { texture in view = texture.pointee.createView!().object }
        guard let view else { throw .invalidResource }
        let color = object(); color["view"] = .object(view)
        switch attachment.loadAction {
        case .load: color["loadOp"] = .string("load")
        case .discard: color["loadOp"] = .string("clear")
        case .clear(let value):
            color["loadOp"] = .string("clear")
            let clear = object(); clear["r"] = .number(Double(value.red)); clear["g"] = .number(Double(value.green)); clear["b"] = .number(Double(value.blue)); clear["a"] = .number(Double(value.alpha)); color["clearValue"] = .object(clear)
        }
        color["storeOp"] = .string(attachment.storeAction == .store ? "store" : "discard")
        let colors = array(); _ = colors.jsObject.push!(color)
        let descriptor = object(); descriptor["colorAttachments"] = .object(colors.jsObject)
        guard let encoder = commandEncoder.beginRenderPass!(descriptor).object else { throw .encoderCreationFailed }
        var drawIndex = pass.drawStart
        let drawEnd = pass.drawStart + pass.drawCount
        while drawIndex < drawEnd {
            let draw = frame[draw: drawIndex]
            guard buffers.withValue(for: draw.vertexBuffer.id, { _ = encoder.setVertexBuffer!(0, $0.pointee) }) != nil,
                  pipelines.withValue(for: draw.pipeline.id, { _ = encoder.setPipeline!($0.pointee) }) != nil else { throw .invalidResource }
            _ = encoder.draw!(draw.vertexCount)
            drawIndex += 1
        }
        _ = encoder.end!()
    }
}
