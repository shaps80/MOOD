import Swift

public struct RenderPass: Sendable {
    public var colorAttachment: ColorAttachment

    package var drawStart: UInt32 = 0
    package var drawCount: UInt32 = 0

    public init(_ colorAttachment: ColorAttachment) {
        self.colorAttachment = colorAttachment
    }
}

public struct RenderPassEncoder {
    private let frame: Frame
    private let passIndex: UInt32

    package init(frame: Frame, passIndex: UInt32) {
        self.frame = frame
        self.passIndex = passIndex
    }

    public func draw(_ command: consuming DrawCommand) {
        frame.append(command, toRenderPassAt: passIndex)
    }
}
