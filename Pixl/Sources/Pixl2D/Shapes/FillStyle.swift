import PixlGraphics

/// Interior paint supported by analytic shapes.
public enum FillStyle: Hashable, Sendable {
    case color(Color)
    case gradient(GradientFill)

    package var paint: Paint {
        switch self {
        case .color(let color): .color(color)
        case .gradient(let gradient): .gradient(gradient)
        }
    }
}
