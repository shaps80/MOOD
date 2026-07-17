import Swift

/// One connected game controller using physical control locations.
public final class Gamepad {
    public struct Events: RandomAccessCollection {
        public typealias Element = Button.Event
        public typealias Index = Int

        fileprivate let storage: Storage

        public var startIndex: Int { 0 }
        public var endIndex: Int { storage.events.count }

        public subscript(position: Int) -> Button.Event {
            storage.events[position]
        }
    }

    public enum Button: UInt8, CaseIterable, Hashable, Sendable {
        case south, east, west, north
        case leftShoulder, rightShoulder
        case leftTrigger, rightTrigger
        case leftStick, rightStick
        case up, down, left, right
        case menu, options
    }

    public let index: Int
    public package(set) var name: String
    public package(set) var isConnected: Bool

    public private(set) var leftStick = SIMD2<Double>.zero
    public private(set) var rightStick = SIMD2<Double>.zero

    private static let eventCapacity = Button.allCases.count * 2
    private static let buttonWordCount = (Button.allCases.count + 63) / 64

    fileprivate final class Storage {
        var events: ContiguousArray<Button.Event> = []
        var pending: ContiguousArray<Button.Event> = []
        var eventIndices: ContiguousArray<Int8>
        var pendingIndices: ContiguousArray<Int8>

        init(capacity: Int) {
            eventIndices = ContiguousArray(repeating: -1, count: capacity)
            pendingIndices = ContiguousArray(repeating: -1, count: capacity)
            events.reserveCapacity(capacity)
            pending.reserveCapacity(capacity)
        }
    }

    private let storage = Storage(capacity: eventCapacity)
    private var pressed: ContiguousArray<UInt64>
    private var values: ContiguousArray<Double>

    package init(index: Int, name: String) {
        self.index = index
        self.name = name
        isConnected = true
        pressed = ContiguousArray(
            repeating: 0,
            count: Self.buttonWordCount
        )
        values = ContiguousArray(
            repeating: 0,
            count: Button.allCases.count
        )
    }

    public var events: Events {
        Events(storage: storage)
    }

    public func contains(_ button: Button) -> Bool {
        let index = Int(button.rawValue)
        return pressed[index >> 6] & (1 << UInt64(index & 63)) != 0
    }

    public func contains(_ button: Button, phase: Button.Phase) -> Bool {
        self.button(button, phase: phase) != nil
    }

    public func value(for button: Button) -> Double {
        values[Int(button.rawValue)]
    }

    public func button(_ button: Button, phase: Button.Phase) -> Button.Event? {
        let index = storage.eventIndices[eventIndex(for: button, phase: phase)]
        guard index >= 0 else { return nil }
        return storage.events[Int(index)]
    }

    package func update(
        _ button: Button,
        value: Double,
        pressed isPressed: Bool
    ) {
        let normalizedValue = min(max(value, 0), 1)
        values[Int(button.rawValue)] = normalizedValue

        let wasPressed = contains(button)
        guard isPressed != wasPressed else { return }
        setPressed(isPressed, for: button)

        let phase: Button.Phase = isPressed ? .down : .up
        let eventIndex = eventIndex(for: button, phase: phase)
        guard storage.pendingIndices[eventIndex] < 0 else { return }
        guard storage.pending.count < Self.eventCapacity else { return }

        storage.pendingIndices[eventIndex] = Int8(storage.pending.count)
        storage.pending.append(.init(
            button: button,
            phase: phase,
            value: normalizedValue
        ))
    }

    package func updateSticks(
        left: SIMD2<Double>,
        right: SIMD2<Double>
    ) {
        leftStick = left
        rightStick = right
    }

    package func publishPendingEvents() {
        swap(&storage.events, &storage.pending)
        swap(&storage.eventIndices, &storage.pendingIndices)
        storage.pending.removeAll(keepingCapacity: true)
        for index in storage.pendingIndices.indices {
            storage.pendingIndices[index] = -1
        }
    }

    package func disconnect() {
        guard isConnected else { return }
        isConnected = false
        leftStick = .zero
        rightStick = .zero
        for button in Button.allCases where contains(button) {
            update(button, value: 0, pressed: false)
        }
    }

    package func reconnect(name: String) {
        self.name = name
        isConnected = true
    }

    private func setPressed(_ value: Bool, for button: Button) {
        let index = Int(button.rawValue)
        let word = index >> 6
        let mask = UInt64(1) << UInt64(index & 63)
        if value {
            pressed[word] |= mask
        } else {
            pressed[word] &= ~mask
        }
    }

    private func eventIndex(for button: Button, phase: Button.Phase) -> Int {
        Int(button.rawValue) * 2 + (phase == .down ? 0 : 1)
    }
}

public extension Gamepad.Button {
    struct Event: Hashable, Sendable {
        public let button: Gamepad.Button
        public let phase: Phase
        public let value: Double

        public init(button: Gamepad.Button, phase: Phase, value: Double) {
            self.button = button
            self.phase = phase
            self.value = value
        }
    }

    enum Phase: Hashable, Sendable {
        case down
        case up
    }
}
