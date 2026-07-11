import Swift

public enum Pass {
    case render(RenderPass)
    case compute(ComputePass)
}

public final class Frame {
    private let passes: UnsafeMutablePointer<Pass>

    public let passCapacity: UInt32
    package private(set) var passCount: UInt32 = 0

    package subscript(index: UInt32) -> Pass {
        passes[.init(index)]
    }

    package subscript(index: Int) -> Pass {
        passes[index]
    }

    public init(passCapacity: UInt32) {
        precondition(passCapacity > 0, "Frame pass capacity must be greater than zero")

        self.passCapacity = passCapacity
        passes = .allocate(capacity: Int(passCapacity))
    }

    deinit {
        reset()
        passes.deallocate()
    }

    public func reset() {
        passes.deinitialize(count: Int(passCount))
        passCount = 0
    }

    public func append(_ pass: consuming Pass) {
        precondition(passCount < passCapacity, "Frame pass capacity exceeded")

        passes.advanced(by: Int(passCount)).initialize(to: pass)
        passCount += 1
    }
}
