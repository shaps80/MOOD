import Swift
import Atomics

final class BorrowState: @unchecked Sendable {
    private let value = ManagedAtomic<Int>(0)

    func acquireRead() -> Bool {
        let previous = value.loadThenWrappingIncrement(
            ordering: .acquiringAndReleasing
        )
        if previous >= 0 { return true }
        value.wrappingDecrement(ordering: .releasing)
        return false
    }

    func releaseRead() {
        value.wrappingDecrement(ordering: .releasing)
    }

    func acquireWrite() -> Bool {
        value.compareExchange(
            expected: 0,
            desired: -1,
            ordering: .acquiringAndReleasing
        ).exchanged
    }

    func releaseWrite() {
        value.store(0, ordering: .releasing)
    }

    var isBorrowed: Bool {
        value.load(ordering: .acquiring) != 0
    }
}
