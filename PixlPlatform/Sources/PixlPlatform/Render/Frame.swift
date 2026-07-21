import Swift

package enum RecordedPass {
    case render(RecordedRenderPass)
}

/// Reusable fixed-capacity storage for ordered render passes and commands.
///
/// A frame records portable commands without allocating after initialization.
/// Call ``reset()`` only after its previous recording is no longer needed.
public final class Frame {
    private let passes: UnsafeMutablePointer<RecordedPass>
    private let commands: UnsafeMutablePointer<RenderCommand>
    private let bytes: UnsafeMutableRawPointer

    /// Maximum number of passes in one recording.
    public let passCapacity: UInt32
    /// Maximum number of encoder commands in one recording.
    public let commandCapacity: UInt32
    /// Maximum frame-owned byte payload across small constants and vertex data.
    public let byteCapacity: UInt32
    package private(set) var passCount: UInt32 = 0
    package private(set) var commandCount: UInt32 = 0
    package private(set) var byteCount: UInt32 = 0
    /// Number of indexed and non-indexed draws currently recorded.
    public private(set) var drawCount: UInt32 = 0

    package subscript(index: UInt32) -> RecordedPass {
        passes[.init(index)]
    }

    package subscript(index: Int) -> RecordedPass {
        passes[index]
    }

    package subscript(command index: UInt32) -> RenderCommand {
        commands[Int(index)]
    }

    /// Allocates fixed recording storage.
    /// - Parameters:
    ///   - passCapacity: Positive maximum pass count.
    ///   - commandCapacity: Positive maximum encoder-command count.
    ///   - byteCapacity: Positive maximum frame-owned byte payload.
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

    /// Discards every recorded pass, command, byte payload, and draw count.
    public func reset() {
        passes.deinitialize(count: Int(passCount))
        commands.deinitialize(count: Int(commandCount))
        passCount = 0
        commandCount = 0
        byteCount = 0
        drawCount = 0
    }

    private func append(_ pass: consuming RecordedPass) {
        precondition(
            passCount < passCapacity,
            "Frame pass capacity exceeded: capacity \(passCapacity), attempted count \(UInt64(passCount) + 1)"
        )

        passes.advanced(by: Int(passCount)).initialize(to: pass)
        passCount += 1
    }

    /// Begins a render pass whose commands must be recorded contiguously.
    /// - Parameter descriptor: Colour attachment and its load/store behaviour.
    /// - Returns: A lightweight encoder that appends commands to this frame.
    public func beginRenderPass(
        _ descriptor: consuming RenderPassDescriptor
    ) -> RenderPassEncoder {
        let index = passCount
        append(.render(RecordedRenderPass(descriptor: descriptor)))
        return .init(frame: self, passIndex: index)
    }

    package func append(_ command: consuming RenderCommand, toRenderPassAt passIndex: UInt32) {
        precondition(passIndex < passCount, "Render pass does not belong to this frame")
        precondition(
            commandCount < commandCapacity,
            "Frame command capacity exceeded: capacity \(commandCapacity), attempted count \(UInt64(commandCount) + 1)"
        )

        guard case .render(var pass) = passes[Int(passIndex)] else {
            preconditionFailure("Draw commands can only be appended to render passes")
        }

        switch command {
        case .setRenderPipeline:
            pass.hasRenderPipeline = true
        case .drawPrimitives, .drawIndexedPrimitives:
            precondition(
                pass.hasRenderPipeline,
                "A render pipeline must be set before drawing"
            )
            drawCount += 1
        case .setVertexBuffer,
             .setVertexBytes,
             .setVertexData,
             .setFragmentTexture,
             .setFragmentSampler:
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

    package func colorFormat(forRenderPassAt passIndex: UInt32) -> PixelFormat {
        precondition(passIndex < passCount, "Render pass does not belong to this frame")

        guard case .render(let pass) = passes[Int(passIndex)] else {
            preconditionFailure("Expected a render pass")
        }
        return pass.descriptor.colorAttachment.target.texture.descriptor.format
    }

    package func appendVertexBytes(
        _ source: UnsafeRawBufferPointer,
        index: UInt32,
        toRenderPassAt passIndex: UInt32
    ) {
        precondition(!source.isEmpty, "Vertex bytes must not be empty")
        precondition(source.count <= 4 * 1024, "Vertex bytes must not exceed 4 KiB")

        let count = UInt32(source.count)
        precondition(
            count <= byteCapacity - byteCount,
            "Frame byte capacity exceeded: capacity \(byteCapacity) bytes, attempted total \(UInt64(byteCount) + UInt64(count)) bytes"
        )

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

    package func appendVertexData(
        _ source: UnsafeRawBufferPointer,
        index: UInt32,
        toRenderPassAt passIndex: UInt32
    ) {
        precondition(!source.isEmpty, "Vertex data must not be empty")
        let count = UInt32(source.count)
        precondition(
            count <= byteCapacity - byteCount,
            "Frame byte capacity exceeded: capacity \(byteCapacity) bytes, attempted total \(UInt64(byteCount) + UInt64(count)) bytes"
        )

        let offset = byteCount
        bytes.advanced(by: Int(offset)).copyMemory(
            from: source.baseAddress!,
            byteCount: source.count
        )
        byteCount += count
        append(
            .setVertexData(offset: offset, count: count, index: index),
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
