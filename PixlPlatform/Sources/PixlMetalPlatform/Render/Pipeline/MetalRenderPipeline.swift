import Metal
import PixlPlatform

struct MetalRenderPipeline {
    let state: MTLRenderPipelineState
    let topology: MTLPrimitiveType

    init(state: MTLRenderPipelineState, topology: MTLPrimitiveType) {
        self.state = state
        self.topology = topology
    }
}
