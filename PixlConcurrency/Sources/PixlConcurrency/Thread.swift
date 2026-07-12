import PixlConcurrencyC

private final class ThreadEntry: @unchecked Sendable {
    let body: @Sendable () -> Void

    init(_ body: @escaping @Sendable () -> Void) {
        self.body = body
    }
}

private func threadMain(
    _ rawEntry: UnsafeMutableRawPointer?
) -> UnsafeMutableRawPointer? {
    guard let rawEntry else { return nil }
    let entry = Unmanaged<ThreadEntry>
        .fromOpaque(rawEntry)
        .takeRetainedValue()
    entry.body()
    return nil
}

final class Thread: @unchecked Sendable {
    private var handle: UnsafeMutableRawPointer?
    private var pendingEntry: UnsafeMutableRawPointer?

    init(_ body: @escaping @Sendable () -> Void) {
        pendingEntry = Unmanaged.passRetained(ThreadEntry(body)).toOpaque()
    }

    deinit {
        if let pendingEntry {
            Unmanaged<ThreadEntry>.fromOpaque(pendingEntry).release()
        }
        precondition(handle == nil, "Thread must be joined before deinit")
    }

    func start() {
        precondition(handle == nil)
        guard let pendingEntry else { preconditionFailure("Thread already started") }

        var status: Int32 = 0
        let newHandle = pixl_thread_create(threadMain, pendingEntry, &status)
        guard let newHandle, status == 0 else {
            preconditionFailure("Thread creation failed: \(status)")
        }

        handle = newHandle
        self.pendingEntry = nil
    }

    func join() {
        guard let handle else { return }
        precondition(pixl_thread_join_and_destroy(handle) == 0)
        self.handle = nil
    }
}
