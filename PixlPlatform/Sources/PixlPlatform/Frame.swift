import Swift

public enum Pass {
    case render(RenderPass)
    case compute(ComputePass)
}

public struct Frame {
    public var passes: [Pass]

    public init(passes: [Pass] = []) {
        self.passes = passes
    }
}
