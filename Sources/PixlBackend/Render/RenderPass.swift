import Swift

public struct RenderPass: Sendable {
    public var colorAttachment: ColorAttachment
    public init(_ colorAttachment: ColorAttachment) {
        self.colorAttachment = colorAttachment
    }
}
