import Atomics
import Swift

public final class AtomicFlag: Sendable {
    private let value: ManagedAtomic<Bool>

    public init(_ value: Bool) {
        self.value = ManagedAtomic(value)
    }

    public func store(_ value: Bool) {
        self.value.store(value, ordering: .releasing)
    }

    public func load() -> Bool {
        value.load(ordering: .acquiring)
    }

    public func exchange(_ value: Bool) -> Bool {
        self.value.exchange(
            value,
            ordering: .acquiringAndReleasing
        )
    }
}
