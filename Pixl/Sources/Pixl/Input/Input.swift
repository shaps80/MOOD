import Swift

/// A game-defined semantic input resolved from one or more physical bindings.
public struct Input {
    /// Direction of a semantic input transition.
    public enum Phase: Hashable, Sendable {
        /// Combined input value changed from zero to active.
        case down
        /// Combined input value changed from active to zero.
        case up
    }

    struct State {
        var value = 0.0
        var previousValue = 0.0
    }

    final class Storage {
        var states: ContiguousArray<State> = []
    }

    private let storage: Storage
    private let index: Int

    init(storage: Storage, index: Int) {
        self.storage = storage
        self.index = index
    }

    func index(in storage: Storage) -> Int? {
        self.storage === storage ? index : nil
    }

    /// The strongest currently active binding, normalized to `0...1`.
    public var value: Double {
        storage.states[index].value
    }

    /// Returns whether the combined semantic input changed to this phase
    /// during the current presentation frame.
    /// - Parameter phase: Transition direction to query.
    /// - Returns: `true` when the transition occurred this frame.
    public func `is`(_ phase: Phase) -> Bool {
        let state = storage.states[index]
        return switch phase {
        case .down:
            state.value > 0 && state.previousValue == 0
        case .up:
            state.value == 0 && state.previousValue > 0
        }
    }
}
