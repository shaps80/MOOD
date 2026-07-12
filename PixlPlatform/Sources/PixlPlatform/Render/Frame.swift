import Swift

package enum RecordedPass {
    case render(RecordedRenderPass)
}

public final class Frame {
    private let passes: UnsafeMutablePointer<RecordedPass>
    private let commands: UnsafeMutablePointer<RenderCommand>
    private let bytes: UnsafeMutableRawPointer

    public let passCapacity: UInt32
    public let commandCapacity: UInt32
    public let byteCapacity: UInt32
    package private(set) var passCount: UInt32 = 0
    package private(set) var commandCount: UInt32 = 0
    package private(set) var byteCount: UInt32 = 0

    package subscript(index: UInt32) -> RecordedPass {
        passes[.init(index)]
    }

    package subscript(index: Int) -> RecordedPass {
        passes[index]
    }

    package subscript(command index: UInt32) -> RenderCommand {
        commands[Int(index)]
    }

    public init(
        passCapacity: UInt32,
        commandCapacity: UInt32,
        byteCapacity: UInt32
    ) {
        precondition(passCapacity > 0, "Frame pass capacity must be greater than zero")
        precondition(commandCapacity > 0, "Frame command capacity must be greater than zero")
        precondition(byteCapacity > 0, "Frame byte capacity must be greater than zero")

        self.passCapacity = passCapacity
        self.commandCapacity = commandCapacity
        self.byteCapacity = byteCapacity
        passes = .allocate(capacity: Int(passCapacity))
        commands = .allocate(capacity: Int(commandCapacity))
        bytes = .allocate(byteCount: Int(byteCapacity), alignment: 16)
    }

    deinit {
        reset()
        passes.deallocate()
        commands.deallocate()
        bytes.deallocate()
    }

    public func reset() {
        passes.deinitialize(count: Int(passCount))
        commands.deinitialize(count: Int(commandCount))
        passCount = 0
        commandCount = 0
        byteCount = 0
    }

    private func append(_ pass: consuming RecordedPass) {
        precondition(passCount < passCapacity, "Frame pass capacity exceeded")

        passes.advanced(by: Int(passCount)).initialize(to: pass)
        passCount += 1
    }

    public func beginRenderPass(
        _ descriptor: consuming RenderPassDescriptor
    ) -> RenderPassEncoder {
        let index = passCount
        append(.render(RecordedRenderPass(descriptor: descriptor)))
        return .init(frame: self, passIndex: index)
    }

    package func append(_ command: consuming RenderCommand, toRenderPassAt passIndex: UInt32) {
        precondition(passIndex < passCount, "Render pass does not belong to this frame")
        precondition(commandCount < commandCapacity, "Frame command capacity exceeded")

        guard case .render(var pass) = passes[Int(passIndex)] else {
            preconditionFailure("Draw commands can only be appended to render passes")
        }

        switch command {
        case .setRenderPipeline:
            pass.hasRenderPipeline = true
        case .drawPrimitives:
            precondition(
                pass.hasRenderPipeline,
                "A render pipeline must be set before drawing"
            )
        case .setVertexBuffer, .setVertexBytes:
            break
        }

        if pass.commandCount == 0 {
            pass.commandStart = commandCount
        } else {
            precondition(
                pass.commandStart + pass.commandCount == commandCount,
                "Commands for a render pass must be recorded contiguously"
            )
        }

        commands.advanced(by: Int(commandCount)).initialize(to: command)
        commandCount += 1
        pass.commandCount += 1
        passes[Int(passIndex)] = .render(pass)
    }

    package func appendVertexBytes(
        _ source: UnsafeRawBufferPointer,
        index: UInt32,
        toRenderPassAt passIndex: UInt32
    ) {
        precondition(!source.isEmpty, "Vertex bytes must not be empty")
        precondition(source.count <= 4 * 1024, "Vertex bytes must not exceed 4 KiB")

        let count = UInt32(source.count)
        precondition(count <= byteCapacity - byteCount, "Frame byte capacity exceeded")

        let offset = byteCount
        bytes.advanced(by: Int(offset)).copyMemory(
            from: source.baseAddress!,
            byteCount: source.count
        )
        byteCount += count
        append(
            .setVertexBytes(offset: offset, count: count, index: index),
            toRenderPassAt: passIndex
        )
    }

    package func withBytes<Result>(
        offset: UInt32,
        count: UInt32,
        _ body: (UnsafeRawBufferPointer) throws -> Result
    ) rethrows -> Result {
        precondition(offset <= byteCount)
        precondition(count <= byteCount - offset)
        return try body(
            UnsafeRawBufferPointer(
                start: bytes.advanced(by: Int(offset)),
                count: Int(count)
            )
        )
    }
}
