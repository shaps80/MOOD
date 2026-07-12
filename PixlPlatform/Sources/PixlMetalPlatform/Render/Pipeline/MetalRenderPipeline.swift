import Metal
import PixlPlatform

struct MetalRenderPipeline {
    let state: MTLRenderPipelineState

    init(state: MTLRenderPipelineState) {
        self.state = state
    }
}
