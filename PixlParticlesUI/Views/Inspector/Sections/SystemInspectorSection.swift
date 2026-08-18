import SwiftUI

struct SystemInspectorSection: View {
    @Binding var duration: Double
    @Binding var particleCount: Double
    @Binding var seed: Double

    var body: some View {
        Section("System") {
            LabeledContent("Duration") {
                Field(value: $duration, step: 5, range: 0 ... .infinity)
            }
            LabeledContent("Particles") {
                Field(
                    value: $particleCount,
                    step: particleCount > 100_000 ? 100_000 : 1_000,
                    range: 0 ... .infinity
                )
            }
            LabeledContent("Seed") {
                Field(value: $seed, range: 0 ... .infinity)
            }
        }
    }
}
