import Metal
import PixlPlatform

extension Color {
    var metalClearColor: MTLClearColor {
        MTLClearColor(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha)
        )
    }
}
