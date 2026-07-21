import Swift

/// One connected game controller using physical control locations.
public final class Gamepad {
    /// Allocation-free random-access view of button transitions published for this frame.
    public struct Events: RandomAccessCollection {
        /// Transition element type.
        public typealias Element = Button.Event
        /// Integer collection index.
        public typealias Index = Int

        fileprivate let storage: Storage

        /// Index of the first transition.
        public var startIndex: Int { 0 }
        /// Position one past the final transition.
        public var endIndex: Int { storage.events.count }

        /// Returns the transition at a valid collection index.
        /// - Parameter position: Index between ``startIndex`` and ``endIndex``.
        /// - Returns: The transition at `position`.
        public subscript(position: Int) -> Button.Event {
            storage.events[position]
        }
    }

    /// Physical controller control locations, independent of vendor labels.
    public enum Button: UInt8, CaseIterable, Hashable, Sendable {
        /// South, east, west, and north face buttons.
        case south, east, west, north
        /// Left and right shoulder buttons.
        case leftShoulder, rightShoulder
        /// Left and right triggers, exposing normalized analogue values.
        case leftTrigger, rightTrigger
        /// Left and right stick-press buttons.
        case leftStick, rightStick
        /// Directional-pad buttons.
        case up, down, left, right
        /// Menu and options controls.
        case menu, options
    }

    /// Stable player-slot index assigned by the platform.
    public let index: Int
    /// Platform-reported controller name.
    public package(set) var name: String
    /// Whether this controller is currently connected.
    public package(set) var isConnected: Bool

    /// Current normalized left-stick displacement with positive y upward.
    public private(set) var leftStick = SIMD2<Float>.zero
    /// Current normalized right-stick displacement with positive y upward.
    public private(set) var rightStick = SIMD2<Float>.zero

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
    private var values: ContiguousArray<Float>

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

    /// Ordered, coalesced button transitions for the current presentation frame.
    public var events: Events {
        Events(storage: storage)
    }

    /// Returns whether a button is currently pressed.
    /// - Parameter button: Physical button to query.
    /// - Returns: `true` while `button` is pressed.
    public func contains(_ button: Button) -> Bool {
        let index = Int(button.rawValue)
        return pressed[index >> 6] & (1 << UInt64(index & 63)) != 0
    }

    /// Returns whether this frame contains a matching button transition.
    /// - Parameters:
    ///   - button: Physical button to query.
    ///   - phase: Transition direction to match.
    /// - Returns: `true` when the current frame contains that transition.
    public func contains(_ button: Button, phase: Button.Phase) -> Bool {
        self.button(button, phase: phase) != nil
    }

    /// Returns a button's current normalized analogue value.
    /// - Parameter button: Physical button to query.
    /// - Returns: Value in `0...1`; digital buttons naturally report `0` or `1`.
    public func value(for button: Button) -> Float {
        values[Int(button.rawValue)]
    }

    /// Returns this frame's matching button transition, if one exists.
    /// - Parameters:
    ///   - button: Physical button to query.
    ///   - phase: Transition direction to match.
    /// - Returns: The coalesced event, or `nil` when no match occurred this frame.
    public func button(_ button: Button, phase: Button.Phase) -> Button.Event? {
        let index = storage.eventIndices[eventIndex(for: button, phase: phase)]
        guard index >= 0 else { return nil }
        return storage.events[Int(index)]
    }

    package func update(
        _ button: Button,
        value: Float,
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
        left: SIMD2<Float>,
        right: SIMD2<Float>
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
    /// One button transition published for a presentation frame.
    struct Event: Hashable, Sendable {
        /// Physical button that transitioned.
        public let button: Gamepad.Button
        /// Whether the button moved down or up.
        public let phase: Phase
        /// Normalized analogue value at the transition.
        public let value: Float

        /// Creates a button transition.
        /// - Parameters:
        ///   - button: Physical button that transitioned.
        ///   - phase: Whether the button moved down or up.
        ///   - value: Normalized analogue value in `0...1`.
        public init(button: Gamepad.Button, phase: Phase, value: Float) {
            self.button = button
            self.phase = phase
            self.value = value
        }
    }

    /// Direction of a physical button transition.
    enum Phase: Hashable, Sendable {
        /// The button became pressed.
        case down
        /// The button stopped being pressed.
        case up
    }
}
