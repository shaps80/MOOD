import Metal
import PixlPlatform

extension Color {
    var metalClearColor: MTLClearColor {
        MTLClearColor(
            red: Double(self[0]),
            green: Double(self[1]),
            blue: Double(self[2]),
            alpha: Double(self[3])
        )
    }
}
