import PixlParticles
import SwiftUI

struct ColorInspectorSection: View {
    @Environment(\.self) private var environment
    @Binding var color: PixlParticles.Color

    var body: some View {
        Section("Colour") {
            ColorPicker(
                "Colour",
                selection: swiftUIColor,
                supportsOpacity: true
            )
        }
    }

    private var swiftUIColor: Binding<SwiftUI.Color> {
        Binding(
            get: {
                SwiftUI.Color(
                    .sRGBLinear,
                    red: Double(color.red),
                    green: Double(color.green),
                    blue: Double(color.blue),
                    opacity: Double(color.alpha)
                )
            },
            set: { value in
                let resolved = value.resolve(in: environment)
                color = .init(
                    red: resolved.linearRed,
                    green: resolved.linearGreen,
                    blue: resolved.linearBlue,
                    alpha: resolved.opacity
                )
            }
        )
    }
}
