import PixlConcurrencyC

final class Condition: @unchecked Sendable {
    private let handle: OpaquePointer

    init() {
        guard let handle = pixl_condition_create() else {
            preconditionFailure("Condition creation failed")
        }
        self.handle = handle
    }

    deinit {
        pixl_condition_destroy(handle)
    }

    @inline(__always)
    func lock() {
        precondition(pixl_condition_lock(handle) == 0)
    }

    @inline(__always)
    func unlock() {
        precondition(pixl_condition_unlock(handle) == 0)
    }

    @inline(__always)
    func wait() {
        precondition(pixl_condition_wait(handle) == 0)
    }

    @inline(__always)
    func broadcast() {
        precondition(pixl_condition_broadcast(handle) == 0)
    }
}
