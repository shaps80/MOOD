import Metal
import PixlRenderer

final class MetalComputeEncoder: PixlRenderer.ComputeEncoder {
    private let value: any MTLComputeCommandEncoder

    var label: String? {
        get { value.label }
        set { value.label = newValue }
    }

    init(_ value: any MTLComputeCommandEncoder) { self.value = value }

    func setPipeline(_ pipeline: any PixlRenderer.ComputePipeline) {
        value.setComputePipelineState((pipeline as! MetalComputePipeline).value)
    }

    func setBuffer(_ buffer: any PixlRenderer.Buffer, index: Int) {
        value.setBuffer((buffer as! MetalBuffer).value, offset: 0, index: index)
    }

    func setBytes(_ bytes: UnsafeRawBufferPointer, index: Int) {
        value.setBytes(bytes.baseAddress!, length: bytes.count, index: index)
    }

    func dispatchThreadgroups(_ groups: ThreadGrid, threads: ThreadGrid) {
        value.dispatchThreadgroups(groups.metal, threadsPerThreadgroup: threads.metal)
    }

    func dispatchThreads(_ grid: ThreadGrid, threads: ThreadGrid) {
        value.dispatchThreads(grid.metal, threadsPerThreadgroup: threads.metal)
    }

    func endEncoding() { value.endEncoding() }
}

extension ThreadGrid {
    var metal: MTLSize { .init(width: width, height: height, depth: depth) }
}
