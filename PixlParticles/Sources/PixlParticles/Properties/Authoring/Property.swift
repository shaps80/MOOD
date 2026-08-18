import Swift

public struct Property<Output>: Codable, Equatable, Sendable
where Output: Codable & Equatable & Sendable {
    public struct Modifier: Codable, Equatable, Identifiable, Sendable {
        public typealias ID = UInt64

        public var id: ID
        public var operation: Operation
        public var value: Value
        public var variesWith: Variation?

        public init(
            id: ID,
            operation: Operation,
            value: Value,
            variesWith: Variation? = nil
        ) {
            self.id = id
            self.operation = operation
            self.value = value
            self.variesWith = variesWith
        }
    }

    public enum Operation: String, Codable, Equatable, Sendable {
        case set
        case add
        case subtract
        case multiply
        case divide
        case lessThan
        case lessOrEqual
        case greaterThan
        case greaterOrEqual
    }

    public enum Value: Codable, Equatable, Sendable {
        case constant(Output)
        case random(
            from: Output,
            to: Output,
            variation: RandomVariation
        )
        case curve([Keyframe])

        public static func random(
            from: Output,
            to: Output
        ) -> Self {
            .random(
                from: from,
                to: to,
                variation: .proportional
            )
        }
    }

    public struct Keyframe: Codable, Equatable, Sendable {
        public var at: Float
        public var value: KeyframeValue
        public var interpolation: Interpolation?

        public init(
            at: Float,
            value: KeyframeValue,
            interpolation: Interpolation? = nil
        ) {
            self.at = at
            self.value = value
            self.interpolation = interpolation
        }
    }

    public enum KeyframeValue: Codable, Equatable, Sendable {
        case constant(Output)
        case random(
            from: Output,
            to: Output,
            variation: RandomVariation
        )

        public static func random(
            from: Output,
            to: Output
        ) -> Self {
            .random(
                from: from,
                to: to,
                variation: .proportional
            )
        }
    }

    public enum RandomVariation: String, Codable, Equatable, Sendable {
        case proportional
        case perValue
    }

    public enum Interpolation: String, Codable, Equatable, Sendable {
        case step
        case linear
        case easeIn
        case easeOut
        case easeInOut
    }

    public enum Variation: Codable, Equatable, Sendable {
        case life
        case speed(from: Float, to: Float)
        case distance(
            from: DistanceReference,
            near: Float,
            far: Float
        )
        case emitterAge(from: Duration, to: Duration)
        case emitterLoop
    }

    public enum DistanceReference: Codable, Equatable, Sendable {
        case emitterOrigin
        case point(Vec3)
        case camera
    }

    private var modifiers: [Modifier]

    public init() {
        modifiers = []
    }

    public init(_ modifiers: some Sequence<Modifier>) {
        self.modifiers = Array(modifiers)
    }
}

extension Property: RandomAccessCollection, MutableCollection,
    RangeReplaceableCollection
{
    public var startIndex: Int { modifiers.startIndex }
    public var endIndex: Int { modifiers.endIndex }

    public subscript(position: Int) -> Modifier {
        get { modifiers[position] }
        set { modifiers[position] = newValue }
    }

    public func index(after index: Int) -> Int {
        modifiers.index(after: index)
    }

    public func index(before index: Int) -> Int {
        modifiers.index(before: index)
    }

    public mutating func replaceSubrange<Replacement>(
        _ subrange: Range<Int>,
        with replacement: Replacement
    ) where Replacement: Collection, Modifier == Replacement.Element {
        modifiers.replaceSubrange(subrange, with: replacement)
    }
}
