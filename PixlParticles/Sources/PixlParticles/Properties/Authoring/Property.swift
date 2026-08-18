import Swift

public struct Property<Output>: Codable, Equatable, Sendable
where Output: Codable & Equatable & Sendable {
    public struct Modifier: Codable, Equatable, Identifiable, Sendable {
        public typealias ID = UInt64

        public private(set) var id: ID
        public var operation: Operation
        public var value: Value
        public var variesWith: Variation?

        public init(
            operation: Operation,
            value: Value,
            variesWith: Variation? = nil
        ) {
            id = 0
            self.operation = operation
            self.value = value
            self.variesWith = variesWith
        }

        init(
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

        mutating func assignID(_ id: ID) {
            self.id = id
        }

        public static func set(
            _ value: Value,
            variesWith: Variation? = nil
        ) -> Self {
            .init(operation: .set, value: value, variesWith: variesWith)
        }

        public static func set(
            _ value: Output,
            variesWith: Variation? = nil
        ) -> Self {
            .set(.constant(value), variesWith: variesWith)
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

    private enum CodingKeys: String, CodingKey {
        case modifiers
    }

    private var modifiers: [Modifier]
    private var nextModifierID: Modifier.ID

    public init() {
        modifiers = []
        nextModifierID = 1
    }

    public init(_ modifiers: some Sequence<Modifier>) {
        self.init()
        append(contentsOf: modifiers)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        append(
            contentsOf: try container.decode(
                [Modifier].self,
                forKey: .modifiers
            )
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modifiers, forKey: .modifiers)
    }
}

extension Property: RandomAccessCollection, MutableCollection,
    RangeReplaceableCollection
{
    public var startIndex: Int { modifiers.startIndex }
    public var endIndex: Int { modifiers.endIndex }

    public subscript(position: Int) -> Modifier {
        get { modifiers[position] }
        set {
            var replacement = newValue
            if replacement.id == 0 {
                replacement.assignID(modifiers[position].id)
            }
            modifiers[position] = replacement
        }
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
        let retainedIDs = Set(
            modifiers.indices
                .filter { !subrange.contains($0) }
                .map { modifiers[$0].id }
        )
        var usedIDs = retainedIDs
        let assigned = replacement.map { modifier in
            var modifier = modifier
            if modifier.id == 0 || usedIDs.contains(modifier.id) {
                while usedIDs.contains(nextModifierID) {
                    nextModifierID += 1
                }
                modifier.assignID(nextModifierID)
                nextModifierID += 1
            } else if modifier.id >= nextModifierID {
                nextModifierID = modifier.id + 1
            }
            usedIDs.insert(modifier.id)
            return modifier
        }
        modifiers.replaceSubrange(subrange, with: assigned)
    }
}
