import Metal
import PixlRenderer

final class MetalRenderEncoder: PixlRenderer.RenderEncoder {
    private let value: any MTLRenderCommandEncoder

    var label: String? {
        get { value.label }
        set { value.label = newValue }
    }

    init(_ value: any MTLRenderCommandEncoder) { self.value = value }

    func setPipeline(_ pipeline: any PixlRenderer.RenderPipeline) {
        value.setRenderPipelineState((pipeline as! MetalRenderPipeline).value)
    }

    func setDepthState(_ state: any PixlRenderer.DepthState) {
        value.setDepthStencilState((state as! MetalDepthState).value)
    }

    func setVertexBuffer(_ buffer: any PixlRenderer.Buffer, index: Int) {
        value.setVertexBuffer((buffer as! MetalBuffer).value, offset: 0, index: index)
    }

    func setVertexBytes(_ bytes: UnsafeRawBufferPointer, index: Int) {
        value.setVertexBytes(bytes.baseAddress!, length: bytes.count, index: index)
    }

    func drawPrimitives(
        _ primitive: PixlRenderer.Primitive,
        indirectBuffer: any PixlRenderer.Buffer
    ) {
        let type: MTLPrimitiveType = switch primitive { case .point: .point }
        value.drawPrimitives(
            type: type,
            indirectBuffer: (indirectBuffer as! MetalBuffer).value,
            indirectBufferOffset: 0
        )
    }

    func endEncoding() { value.endEncoding() }
}
