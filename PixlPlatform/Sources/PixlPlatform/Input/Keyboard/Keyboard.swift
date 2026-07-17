import Swift

/// Current physical keyboard state and transitions published for this frame.
public final class Keyboard {
    public struct Events: RandomAccessCollection {
        public typealias Element = Key.Event
        public typealias Index = Int

        fileprivate let storage: Storage

        public var startIndex: Int { 0 }
        public var endIndex: Int { storage.events.count }

        public subscript(position: Int) -> Key.Event {
            storage.events[position]
        }
    }

    private static let wordCount = (Key.allCases.count + 63) / 64
    private static let eventCapacity = Key.allCases.count * 2

    fileprivate final class Storage {
        var events: ContiguousArray<Key.Event>
        var pending: ContiguousArray<Key.Event>
        var eventIndices: ContiguousArray<Int16>
        var pendingIndices: ContiguousArray<Int16>

        init(capacity: Int) {
            events = []
            pending = []
            eventIndices = ContiguousArray(repeating: -1, count: capacity)
            pendingIndices = ContiguousArray(repeating: -1, count: capacity)
            events.reserveCapacity(capacity)
            pending.reserveCapacity(capacity)
        }
    }

    private let storage = Storage(capacity: eventCapacity)
    private var down: ContiguousArray<UInt64>

    public package(set) var isFocused = false

    public init() {
        down = ContiguousArray(repeating: 0, count: Self.wordCount)
    }

    public var events: Events {
        Events(storage: storage)
    }

    /// Returns whether the physical key is currently held down.
    public func contains(_ key: Key) -> Bool {
        let index = Int(key.rawValue)
        return down[index >> 6] & (1 << UInt64(index & 63)) != 0
    }

    /// Returns whether this frame contains a matching key transition.
    public func contains(_ key: Key, phase: Key.Phase) -> Bool {
        self.key(key, phase: phase) != nil
    }

    /// Returns this frame's matching transition, if one exists.
    public func key(_ key: Key, phase: Key.Phase) -> Key.Event? {
        let index = storage.eventIndices[eventIndex(for: key, phase: phase)]
        guard index >= 0 else { return nil }
        return storage.events[Int(index)]
    }

    package func publishPendingEvents() {
        swap(&storage.events, &storage.pending)
        swap(&storage.eventIndices, &storage.pendingIndices)
        storage.pending.removeAll(keepingCapacity: true)
        for index in storage.pendingIndices.indices {
            storage.pendingIndices[index] = -1
        }
    }

    package func handle(_ event: Key.Event) {
        let wasDown = contains(event.key)

        switch event.phase {
        case .down:
            guard !wasDown || event.isRepeat else { return }
            setDown(true, for: event.key)
        case .up:
            guard wasDown else { return }
            setDown(false, for: event.key)
        }

        let eventIndex = eventIndex(for: event.key, phase: event.phase)
        guard storage.pendingIndices[eventIndex] < 0 else { return }

        guard storage.pending.count < Self.eventCapacity else { return }
        storage.pendingIndices[eventIndex] = Int16(storage.pending.count)
        storage.pending.append(event)
    }

    package func focus(_ focused: Bool, modifiers: Key.Modifiers = []) {
        guard focused != isFocused else { return }
        isFocused = focused
        guard !focused else { return }

        for key in Key.allCases where contains(key) {
            handle(Key.Event(key: key, phase: .up, modifiers: modifiers))
        }
    }

    private func setDown(_ value: Bool, for key: Key) {
        let index = Int(key.rawValue)
        let word = index >> 6
        let mask = UInt64(1) << UInt64(index & 63)
        if value {
            down[word] |= mask
        } else {
            down[word] &= ~mask
        }
    }

    private func eventIndex(for key: Key, phase: Key.Phase) -> Int {
        Int(key.rawValue) * 2 + (phase == .down ? 0 : 1)
    }
}
