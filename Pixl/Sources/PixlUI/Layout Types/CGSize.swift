import Swift

public struct CGPoint: Codable, Equatable, Sendable, CustomDebugStringConvertible {
    public var x: Double = 0
    public var y: Double = 0

    public init() { }
    
    public init(x: Double, y: Double) {
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
    public var width: Double = 0
    public var height: Double = 0

    public init() { }
    
    public init(width: Double, height: Double) {
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

    public static var zero: Self { .init() }

    public var debugDescription: String {
        "origin: \(origin), size: \(size)"
    }
}
