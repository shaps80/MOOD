import Swift

package enum _ShapePath: Sendable {
    case rectangle(Rect, cornerRadius: Float)
    case unevenRoundedRectangle(Rect, cornerRadii: RectangleCornerRadii)
    case concentricRectangle(Rect, corners: _ConcentricCornerStyles)
    case circle(Rect)
}
