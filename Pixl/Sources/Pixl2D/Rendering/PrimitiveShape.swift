import PixlGraphics

/// Lightweight two-dimensional geometry for immediate drawing.
public enum PrimitiveShape: Equatable, Sendable {
    /// A rectangle described in local coordinates.
    case rect(Rect)
    /// An ellipse inscribed within a rectangle in local coordinates.
    case ellipse(in: Rect)
}

public extension PrimitiveShape {
    /// Visual treatment applied when drawing a primitive shape.
    enum Style: Equatable, Sendable {
        /// Covers the primitive interior with one colour.
        case fill(Color)
        /// Draws only the primitive boundary.
        ///
        /// Width is measured in logical screen units and is therefore
        /// independent of camera zoom and physical display scale.
        case stroke(Color, width: Float)
    }
}
