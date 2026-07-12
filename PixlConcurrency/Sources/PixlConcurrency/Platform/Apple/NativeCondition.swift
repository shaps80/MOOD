#if canImport(Darwin)
import Darwin

final class NativeCondition: @unchecked Sendable {
    private var mutex = pthread_mutex_t()
    private var condition = pthread_cond_t()

    init() {
        precondition(pthread_mutex_init(&mutex, nil) == 0)
        precondition(pthread_cond_init(&condition, nil) == 0)
    }

    deinit {
        precondition(pthread_cond_destroy(&condition) == 0)
        precondition(pthread_mutex_destroy(&mutex) == 0)
    }

    @inline(__always)
    func lock() {
        precondition(pthread_mutex_lock(&mutex) == 0)
    }

    @inline(__always)
    func unlock() {
        precondition(pthread_mutex_unlock(&mutex) == 0)
    }

    @inline(__always)
    func wait() {
        precondition(pthread_cond_wait(&condition, &mutex) == 0)
    }

    @inline(__always)
    func broadcast() {
        precondition(pthread_cond_broadcast(&condition) == 0)
    }
}
#endif
