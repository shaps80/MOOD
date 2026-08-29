import Swift

/// A two-dimensional single-precision position.
public typealias Point = SIMD2<Float>

/// A two-dimensional single-precision size.
public typealias Size = SIMD2<Float>

public extension Point {
    @inlinable init(x: Int, y: Int) {
        self.init(Float(x), Float(y))
    }
}

public extension Size {
    @inlinable init(width: Float, height: Float) {
        self.init(width, height)
    }

    @inlinable init(width: Int, height: Int) {
        self.init(Float(width), Float(height))
    }

    var width: Float {
        @inlinable get { x }
        @inlinable set { x = newValue }
    }

    var height: Float {
        @inlinable get { y }
        @inlinable set { y = newValue }
    }
}
