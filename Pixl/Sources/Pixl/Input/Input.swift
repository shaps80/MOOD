import Swift

/// A game-defined semantic input resolved from one or more physical bindings.
public struct Input {
    public enum Phase: Hashable, Sendable {
        case down
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
