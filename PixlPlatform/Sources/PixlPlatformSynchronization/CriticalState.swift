import Atomics
import Swift

/// Serializes rare control-plane state changes. Real-time callbacks must not
/// acquire this lock.
public final class CriticalState<State>: @unchecked Sendable {
    private let locked = ManagedAtomic<Bool>(false)
    private var state: State

    public init(_ state: consuming State) {
        self.state = state
    }

    public func withLock<Result, Failure: Error>(
        _ body: (inout State) throws(Failure) -> Result
    ) throws(Failure) -> Result {
        while true {
            let result = locked.compareExchange(
                expected: false,
                desired: true,
                ordering: .acquiring
            )
            if result.exchanged { break }
        }
        defer { locked.store(false, ordering: .releasing) }
        return try body(&state)
    }
}
