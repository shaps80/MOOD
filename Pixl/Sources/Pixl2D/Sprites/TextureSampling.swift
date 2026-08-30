/// Describes how a texture is sampled independently of its image content.
public struct TextureSampling: Equatable, Sendable {
    public var filtering: Filtering
    public var addressing: Addressing

    public init(
        filtering: Filtering = .nearest,
        addressing: Addressing = .clampToEdge
    ) {
        self.filtering = filtering
        self.addressing = addressing
    }
}

public extension TextureSampling {
    struct Filtering: Equatable, Sendable {
        public var minification: Filter
        public var magnification: Filter

        public init(
            minification: Filter = .nearest,
            magnification: Filter = .nearest
        ) {
            self.minification = minification
            self.magnification = magnification
        }

        public static let nearest: Self = .init()
        public static let linear: Self = .init(
            minification: .linear,
            magnification: .linear
        )
    }

    enum Filter: Equatable, Sendable {
        case nearest
        case linear
    }

    struct Addressing: Equatable, Sendable {
        public var horizontal: AddressMode
        public var vertical: AddressMode

        public init(
            horizontal: AddressMode = .clampToEdge,
            vertical: AddressMode = .clampToEdge
        ) {
            self.horizontal = horizontal
            self.vertical = vertical
        }

        public static let clampToEdge: Self = .init()
        public static let `repeat`: Self = .init(
            horizontal: .repeat,
            vertical: .repeat
        )
        public static let mirrorRepeat: Self = .init(
            horizontal: .mirrorRepeat,
            vertical: .mirrorRepeat
        )
    }

    enum AddressMode: Equatable, Sendable {
        case clampToEdge
        case `repeat`
        case mirrorRepeat
    }
}
