import Swift

public enum Pass {
    case render(RenderPass)
    case compute(ComputePass)
}

public final class Frame {
    private let passes: UnsafeMutablePointer<Pass>
    private let draws: UnsafeMutablePointer<DrawCommand>

    public let passCapacity: UInt32
    public let drawCapacity: UInt32
    package private(set) var passCount: UInt32 = 0
    package private(set) var drawCount: UInt32 = 0

    package subscript(index: UInt32) -> Pass {
        passes[.init(index)]
    }

    package subscript(index: Int) -> Pass {
        passes[index]
    }

    package subscript(draw index: UInt32) -> DrawCommand {
        draws[Int(index)]
    }

    public init(passCapacity: UInt32, drawCapacity: UInt32) {
        precondition(passCapacity > 0, "Frame pass capacity must be greater than zero")
        precondition(drawCapacity > 0, "Frame draw capacity must be greater than zero")

        self.passCapacity = passCapacity
        self.drawCapacity = drawCapacity
        passes = .allocate(capacity: Int(passCapacity))
        draws = .allocate(capacity: Int(drawCapacity))
    }

    deinit {
        reset()
        passes.deallocate()
        draws.deallocate()
    }

    public func reset() {
        passes.deinitialize(count: Int(passCount))
        draws.deinitialize(count: Int(drawCount))
        passCount = 0
        drawCount = 0
    }

    public func append(_ pass: consuming Pass) {
        precondition(passCount < passCapacity, "Frame pass capacity exceeded")

        passes.advanced(by: Int(passCount)).initialize(to: pass)
        passCount += 1
    }

    public func beginRenderPass(_ pass: consuming RenderPass) -> RenderPassEncoder {
        let index = passCount
        append(.render(pass))
        return .init(frame: self, passIndex: index)
    }

    package func append(_ draw: consuming DrawCommand, toRenderPassAt passIndex: UInt32) {
        precondition(passIndex < passCount, "Render pass does not belong to this frame")
        precondition(drawCount < drawCapacity, "Frame draw capacity exceeded")

        guard case .render(var pass) = passes[Int(passIndex)] else {
            preconditionFailure("Draw commands can only be appended to render passes")
        }

        if pass.drawCount == 0 {
            pass.drawStart = drawCount
        } else {
            precondition(
                pass.drawStart + pass.drawCount == drawCount,
                "Draw commands for a render pass must be recorded contiguously"
            )
        }

        draws.advanced(by: Int(drawCount)).initialize(to: draw)
        drawCount += 1
        pass.drawCount += 1
        passes[Int(passIndex)] = .render(pass)
    }
}
