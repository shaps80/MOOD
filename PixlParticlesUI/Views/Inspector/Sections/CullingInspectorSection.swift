import SwiftUI

struct CullingInspectorSection: View {
    @Binding var isEnabled: Bool
    @Binding var scale: Double

    var body: some View {
        Section("Culling") {
            Toggle("Cull to Bounds", isOn: $isEnabled)
            LabeledContent("Bounds Scale") {
                Field(
                    value: $scale,
                    step: 25,
                    range: 1 ... 10_000
                )
            }
        }
    }
}
