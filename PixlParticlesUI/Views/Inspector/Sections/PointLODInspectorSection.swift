import SwiftUI

struct PointLODInspectorSection: View {
    @Binding var isEnabled: Bool
    @Binding var activation: Double
    @Binding var maximum: Double
    @Binding var tileSize: Double
    @Binding var pointsPerPixel: Double

    var body: some View {
        Section("Point LOD") {
            Toggle("Enabled", isOn: $isEnabled)

            if isEnabled {
                LabeledContent("Activation") {
                    Field(value: $activation, step: 100_000)
                }
                LabeledContent("Maximum") {
                    Field(value: $maximum, step: 100_000)
                }
                LabeledContent("Tile Size") {
                    Field(value: $tileSize, step: 1)
                }
                LabeledContent("Points/Pixel") {
                    Field(value: $pointsPerPixel, step: 1)
                }
            }
        }
    }
}
