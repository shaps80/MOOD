import SwiftUI

struct SystemInspectorSection: View {
    @Binding var duration: Double
    @Binding var spawnRate: Double
    @Binding var lifetime: Double
    @Binding var seed: Double

    var body: some View {
        Section {
            LabeledContent("Duration") {
                Field(value: $duration, step: 5, range: 0 ... .infinity)
            }

            LabeledContent("Spawn Rate") {
                Field(
                    value: $spawnRate,
                    step: spawnRate > 100_000 ? 100_000 : 1_000,
                    range: 0 ... .infinity
                )
            }

            LabeledContent("Lifetime") {
                Field(
                    value: $lifetime,
                    step: 1,
                    range: 0.001 ... .infinity,
                    fractionDigits: 3
                )
            }

            LabeledContent("Seed") {
                Field(value: $seed, range: 0 ... .infinity)
            }
        }
    }
}
