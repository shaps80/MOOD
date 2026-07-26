import Swift

/// A game-defined semantic input resolved from one or more physical bindings.
public struct Input: Hashable, @unchecked Sendable {
    /// Direction of a semantic input transition.
    public enum Phase: Hashable, Sendable {
        case down
        case up
    }

    package struct State {
        package var value: Float = 0
        package var previousValue: Float = 0

        package init() {}
    }

    package final class Storage {
        package var states: ContiguousArray<State> = []

        package init() {}
    }

    package let storage: Storage
    package let index: Int

    package init(storage: Storage, index: Int) {
        self.storage = storage
        self.index = index
    }

    package func index(in storage: Storage) -> Int? {
        self.storage === storage ? index : nil
    }

    public var value: Float {
        storage.states[index].value
    }

    public func `is`(_ phase: Phase) -> Bool {
        let state = storage.states[index]
        return switch phase {
        case .down:
            state.value > 0 && state.previousValue == 0
        case .up:
            state.value == 0 && state.previousValue > 0
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage === rhs.storage && lhs.index == rhs.index
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(storage))
        hasher.combine(index)
    }
}
