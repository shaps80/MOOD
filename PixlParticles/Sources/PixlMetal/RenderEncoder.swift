import Metal
import PixlRenderer

final class MetalRenderEncoder: PixlRenderer.RenderEncoder {
    private let reusableDraw: ReusableDraw
    private let value: any MTLRenderCommandEncoder

    var label: String? {
        get { value.label }
        set { value.label = newValue }
    }

    init(_ value: any MTLRenderCommandEncoder, reusableDraw: ReusableDraw) {
        self.value = value
        self.reusableDraw = reusableDraw
    }

    func setPipeline(_ pipeline: any PixlRenderer.RenderPipeline) {
        value.setRenderPipelineState((pipeline as! MetalRenderPipeline).value)
    }

    func setDepthState(_ state: any PixlRenderer.DepthState) {
        value.setDepthStencilState((state as! MetalDepthState).value)
    }

    func setFragmentBuffer(_ buffer: any PixlRenderer.Buffer, index: Int) {
        value.setFragmentBuffer((buffer as! MetalBuffer).value, offset: 0, index: index)
    }

    func setVertexBuffer(_ buffer: any PixlRenderer.Buffer, index: Int) {
        let metal = (buffer as! MetalBuffer).value
        // ICBs inherit these bindings. Declare their resource usage explicitly.
        if reusableDraw.isSupported { value.useResource(metal, usage: .read, stages: .vertex) }
        value.setVertexBuffer(metal, offset: 0, index: index)
    }

    func setVertexBytes(_ bytes: UnsafeRawBufferPointer, index: Int) {
        value.setVertexBytes(bytes.baseAddress!, length: bytes.count, index: index)
    }

    func drawPrimitives(
        _ primitive: PixlRenderer.Primitive,
        indirectBuffer: any PixlRenderer.Buffer
    ) {
        let type: MTLPrimitiveType = switch primitive {
        case .point: .point
        case .line: .line
        case .triangleStrip: .triangleStrip
        }
        value.drawPrimitives(
            type: type,
            indirectBuffer: (indirectBuffer as! MetalBuffer).value,
            indirectBufferOffset: 0
        )
    }

    func drawPrimitives(
        _ primitive: PixlRenderer.Primitive,
        vertexStart: Int,
        vertexCount: Int
    ) {
        let type: MTLPrimitiveType = switch primitive {
        case .point: .point
        case .line: .line
        case .triangleStrip: .triangleStrip
        }
        value.drawPrimitives(
            type: type,
            vertexStart: vertexStart,
            vertexCount: vertexCount
        )
    }

    func drawPrimitives(
        _ primitive: PixlRenderer.Primitive,
        vertexStart: Int,
        vertexCount: Int,
        instanceCount: Int
    ) {
        let type: MTLPrimitiveType = switch primitive {
        case .point: .point
        case .line: .line
        case .triangleStrip: .triangleStrip
        }
        value.drawPrimitives(
            type: type,
            vertexStart: vertexStart,
            vertexCount: vertexCount,
            instanceCount: instanceCount
        )
    }

    func drawReusablePrimitives(
        _ primitive: PixlRenderer.Primitive, vertexCount: Int, instanceCount: Int
    ) {
        guard vertexCount > 0, instanceCount > 0 else { return }
        let type: MTLPrimitiveType = switch primitive {
        case .point: .point
        case .line: .line
        case .triangleStrip: .triangleStrip
        }
        if let command = reusableDraw.command(
            primitive: type, vertices: vertexCount, instances: instanceCount
        ) {
            value.executeCommandsInBuffer(command, range: 0..<1)
        } else {
            value.drawPrimitives(type: type, vertexStart: 0, vertexCount: vertexCount,
                                 instanceCount: instanceCount)
        }
    }

    func endEncoding() { value.endEncoding() }
}
