import Swift

public struct CGPoint: Codable, Equatable, Sendable, CustomDebugStringConvertible {
    public var x: Float = 0
    public var y: Float = 0

    public init() { }
    
    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
    
    public init(x: Int, y: Int) {
        self.x = .init(x)
        self.y = .init(y)
    }

    public static var zero: Self { .init() }

    public var debugDescription: String {
        "(\(x), \(y))"
    }
}

public struct CGSize: Codable, Equatable, Sendable, CustomDebugStringConvertible {
    public var width: Float = 0
    public var height: Float = 0

    public init() { }
    
    public init(width: Float, height: Float) {
        self.width = width
        self.height = height
    }

    public init(width: Int, height: Int) {
        self.width = .init(width)
        self.height = .init(height)
    }

    public static var zero: Self { .init() }

    public var debugDescription: String {
        "(\(width), \(height))"
    }
}

public struct CGRect: Codable, Equatable, Sendable, CustomDebugStringConvertible {
    public var origin: CGPoint = .zero
    public var size: CGSize = .zero

    public init() { }

    public init(origin: CGPoint, size: CGSize) {
        self.origin = origin
        self.size = size
    }

    public init(x: Float, y: Float, width: Float, height: Float) {
        self.init(origin: .init(x: x, y: y), size: .init(width: width, height: height))
    }

    public var minX: Float { origin.x }
    public var midX: Float { origin.x + size.width / 2 }
    public var maxX: Float { origin.x + size.width }
    public var minY: Float { origin.y }
    public var midY: Float { origin.y + size.height / 2 }
    public var maxY: Float { origin.y + size.height }

    public static var zero: Self { .init() }

    public var debugDescription: String {
        "origin: \(origin), size: \(size)"
    }
}
