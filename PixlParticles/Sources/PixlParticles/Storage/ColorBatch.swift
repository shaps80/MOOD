import Swift

struct ColorBatch {
    var red: SIMD4<Float>
    var green: SIMD4<Float>
    var blue: SIMD4<Float>
    var alpha: SIMD4<Float>

    init(repeating color: Color) {
        let alpha = SIMD4<Float>(repeating: color.alpha)
        red = SIMD4<Float>(repeating: color.red) * alpha
        green = SIMD4<Float>(repeating: color.green) * alpha
        blue = SIMD4<Float>(repeating: color.blue) * alpha
        self.alpha = alpha
    }

    subscript(_ lane: Int) -> Color {
        get {
            let alpha = alpha[lane]
            guard alpha > 0 else {
                return Color(red: 0, green: 0, blue: 0, alpha: 0)
            }
            return Color(
                red: red[lane] / alpha,
                green: green[lane] / alpha,
                blue: blue[lane] / alpha,
                alpha: alpha
            )
        }
        set {
            let alpha = newValue.alpha
            red[lane] = newValue.red * alpha
            green[lane] = newValue.green * alpha
            blue[lane] = newValue.blue * alpha
            self.alpha[lane] = alpha
        }
    }
}
