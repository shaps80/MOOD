import Swift

package struct Color {
    package let red: Half
    package let green: Half
    package let blue: Half
    package let alpha: Half

    package init(
        premultipliedRed: Float,
        premultipliedGreen: Float,
        premultipliedBlue: Float,
        alpha: Float
    ) {
        precondition(alpha >= 0 && alpha <= 1)

        red = Half(premultipliedRed)
        green = Half(premultipliedGreen)
        blue = Half(premultipliedBlue)
        self.alpha = Half(alpha)
    }
}
