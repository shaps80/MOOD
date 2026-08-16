import Swift

package struct Color {
    package let red: Float16
    package let green: Float16
    package let blue: Float16
    package let alpha: Float16

    package init(
        premultipliedRed: Float,
        premultipliedGreen: Float,
        premultipliedBlue: Float,
        alpha: Float
    ) {
        precondition(alpha >= 0 && alpha <= 1)

        red = Float16(premultipliedRed)
        green = Float16(premultipliedGreen)
        blue = Float16(premultipliedBlue)
        self.alpha = Float16(alpha)
    }
}
