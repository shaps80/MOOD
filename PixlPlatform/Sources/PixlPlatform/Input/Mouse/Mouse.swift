import Swift

/// Current physical mouse state and events published for this frame.
public final class Mouse {
    public struct Samples: RandomAccessCollection {
        public typealias Element = Sample
        public typealias Index = Int
        fileprivate let storage: Storage
        public var startIndex: Int { 0 }
        public var endIndex: Int { storage.samples.count }
        public subscript(position: Int) -> Sample { storage.samples[position] }
    }

    public struct ButtonEvents: RandomAccessCollection {
        public typealias Element = Button.Event
        public typealias Index = Int
        fileprivate let storage: Storage
        public var startIndex: Int { 0 }
        public var endIndex: Int { storage.buttonEvents.count }
        public subscript(position: Int) -> Button.Event { storage.buttonEvents[position] }
    }

    public struct ScrollEvents: RandomAccessCollection {
        public typealias Element = ScrollEvent
        public typealias Index = Int
        fileprivate let storage: Storage
        public var startIndex: Int { 0 }
        public var endIndex: Int { storage.scrollEvents.count }
        public subscript(position: Int) -> ScrollEvent { storage.scrollEvents[position] }
    }

    private static let sampleCapacity = 512
    private static let buttonCapacity = 256
    private static let buttonEventCapacity = buttonCapacity * 2
    private static let scrollCapacity = 128

    fileprivate final class Storage {
        var samples: ContiguousArray<Sample> = []
        var pendingSamples: ContiguousArray<Sample> = []
        var buttonEvents: ContiguousArray<Button.Event> = []
        var pendingButtonEvents: ContiguousArray<Button.Event> = []
        var scrollEvents: ContiguousArray<ScrollEvent> = []
        var pendingScrollEvents: ContiguousArray<ScrollEvent> = []
        var eventIndices = ContiguousArray(repeating: Int16(-1), count: buttonEventCapacity)
        var pendingEventIndices = ContiguousArray(repeating: Int16(-1), count: buttonEventCapacity)

        init() {
            samples.reserveCapacity(sampleCapacity)
            pendingSamples.reserveCapacity(sampleCapacity)
            buttonEvents.reserveCapacity(buttonEventCapacity)
            pendingButtonEvents.reserveCapacity(buttonEventCapacity)
            scrollEvents.reserveCapacity(scrollCapacity)
            pendingScrollEvents.reserveCapacity(scrollCapacity)
        }
    }

    private let storage = Storage()
    private var pressed = ContiguousArray(repeating: UInt64(0), count: 4)
    private var pendingTranslation = SIMD2<Float>.zero

    public private(set) var location = SIMD2<Float>.zero
    public private(set) var translation = SIMD2<Float>.zero
    public package(set) var isFocused = false

    public init() {}

    public var samples: Samples { Samples(storage: storage) }
    public var buttonEvents: ButtonEvents { ButtonEvents(storage: storage) }
    public var scrollEvents: ScrollEvents { ScrollEvents(storage: storage) }

    public func isPressed(_ button: Button) -> Bool {
        let index = Int(button.rawValue)
        return pressed[index >> 6] & (UInt64(1) << UInt64(index & 63)) != 0
    }

    public func wasPressed(_ button: Button) -> Bool {
        event(button, phase: .down) != nil
    }

    public func wasReleased(_ button: Button) -> Bool {
        event(button, phase: .up) != nil
    }

    public func event(_ button: Button, phase: Button.Phase) -> Button.Event? {
        let index = storage.eventIndices[eventIndex(button, phase)]
        return index >= 0 ? storage.buttonEvents[Int(index)] : nil
    }

    package func handle(_ sample: Sample) {
        location = sample.location
        pendingTranslation += sample.translation
        guard storage.pendingSamples.count < Self.sampleCapacity else {
            let last = storage.pendingSamples.index(before: storage.pendingSamples.endIndex)
            let previous = storage.pendingSamples[last]
            storage.pendingSamples[last] = Sample(
                timestamp: sample.timestamp,
                location: sample.location,
                translation: previous.translation + sample.translation
            )
            return
        }
        storage.pendingSamples.append(sample)
    }

    package func handle(_ event: Button.Event) {
        location = event.location
        let wasDown = isPressed(event.button)
        switch event.phase {
        case .down:
            guard !wasDown else { return }
            setPressed(true, event.button)
        case .up:
            guard wasDown else { return }
            setPressed(false, event.button)
        }
        let lookup = eventIndex(event.button, event.phase)
        guard storage.pendingEventIndices[lookup] < 0 else { return }
        storage.pendingEventIndices[lookup] = Int16(storage.pendingButtonEvents.count)
        storage.pendingButtonEvents.append(event)
    }

    package func handle(_ event: ScrollEvent) {
        location = event.location
        guard storage.pendingScrollEvents.count < Self.scrollCapacity else {
            let last = storage.pendingScrollEvents.index(before: storage.pendingScrollEvents.endIndex)
            let previous = storage.pendingScrollEvents[last]
            guard previous.unit == event.unit else { return }
            storage.pendingScrollEvents[last] = ScrollEvent(
                timestamp: event.timestamp,
                location: event.location,
                translation: previous.translation + event.translation,
                unit: event.unit
            )
            return
        }
        storage.pendingScrollEvents.append(event)
    }

    package func publishPendingEvents() {
        swap(&storage.samples, &storage.pendingSamples)
        swap(&storage.buttonEvents, &storage.pendingButtonEvents)
        swap(&storage.scrollEvents, &storage.pendingScrollEvents)
        swap(&storage.eventIndices, &storage.pendingEventIndices)
        translation = pendingTranslation
        pendingTranslation = .zero
        storage.pendingSamples.removeAll(keepingCapacity: true)
        storage.pendingButtonEvents.removeAll(keepingCapacity: true)
        storage.pendingScrollEvents.removeAll(keepingCapacity: true)
        for index in storage.pendingEventIndices.indices {
            storage.pendingEventIndices[index] = -1
        }
    }

    package func focus(_ focused: Bool, timestamp: Double = 0) {
        guard focused != isFocused else { return }
        isFocused = focused
        guard !focused else { return }
        for rawValue in UInt8.min...UInt8.max {
            let button = Button(rawValue: rawValue)
            if isPressed(button) {
                handle(.init(timestamp: timestamp, button: button, phase: .up, location: location))
            }
        }
    }

    private func setPressed(_ value: Bool, _ button: Button) {
        let index = Int(button.rawValue)
        let word = index >> 6
        let mask = UInt64(1) << UInt64(index & 63)
        if value { pressed[word] |= mask } else { pressed[word] &= ~mask }
    }

    private func eventIndex(_ button: Button, _ phase: Button.Phase) -> Int {
        Int(button.rawValue) * 2 + (phase == .down ? 0 : 1)
    }
}
