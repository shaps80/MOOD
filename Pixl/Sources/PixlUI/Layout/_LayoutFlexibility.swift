import Swift

struct _LayoutFlexibility {
    var minimum: Float
    var ideal: Float
    var maximum: Float

    var range: Float { maximum - minimum }
}
