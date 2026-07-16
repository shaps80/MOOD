import Metal
import PixlPlatform

struct MetalRenderPipeline {
    let state: MTLRenderPipelineState
    let usesDefaultBindings: Bool

    init(
        state: MTLRenderPipelineState,
        usesDefaultBindings: Bool
    ) {
        self.state = state
        self.usesDefaultBindings = usesDefaultBindings
    }
}
