#if !canImport(Darwin)
import Swift

enum NativeTopology {
    static let current = ExecutionTopology(availableProcessorCount: 1)
}

final class NativeCondition: @unchecked Sendable {
    func lock() {}
    func unlock() {}
    func wait() { preconditionFailure("Native threads are unavailable") }
    func broadcast() {}
}

final class NativeThread: @unchecked Sendable {
    init(_ body: @escaping @Sendable () -> Void) {
        preconditionFailure("Native threads are unavailable")
    }

    func start() {}
    func join() {}
}
#endif
