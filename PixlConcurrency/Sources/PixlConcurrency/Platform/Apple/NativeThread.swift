#if canImport(Darwin)
@preconcurrency import Darwin
import PixlConcurrencyC

private final class NativeThreadEntry: @unchecked Sendable {
    let body: @Sendable () -> Void

    init(_ body: @escaping @Sendable () -> Void) {
        self.body = body
    }
}

private func nativeThreadMain(
    _ rawEntry: UnsafeMutableRawPointer?
) -> UnsafeMutableRawPointer? {
    guard let rawEntry else { return nil }
    let entry = Unmanaged<NativeThreadEntry>
        .fromOpaque(rawEntry)
        .takeRetainedValue()
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0)
    entry.body()
    return nil
}

final class NativeThread: @unchecked Sendable {
    private var thread: UnsafeMutableRawPointer?
    private var pendingEntry: UnsafeMutableRawPointer?

    init(_ body: @escaping @Sendable () -> Void) {
        pendingEntry = Unmanaged.passRetained(
            NativeThreadEntry(body)
        ).toOpaque()
    }

    deinit {
        if let pendingEntry {
            Unmanaged<NativeThreadEntry>
                .fromOpaque(pendingEntry)
                .release()
        }
        precondition(thread == nil, "NativeThread must be joined before deinit")
    }

    func start() {
        precondition(thread == nil)
        guard let pendingEntry else { preconditionFailure("Thread already started") }

        var status: Int32 = 0
        let newThread = pixl_thread_create(
            nativeThreadMain,
            pendingEntry,
            &status
        )
        if let newThread, status == 0 {
            thread = newThread
            self.pendingEntry = nil
        } else {
            preconditionFailure("pthread_create failed: \(status)")
        }
    }

    func join() {
        guard let thread else { return }
        precondition(pixl_thread_join_and_destroy(thread) == 0)
        self.thread = nil
    }
}
#endif
