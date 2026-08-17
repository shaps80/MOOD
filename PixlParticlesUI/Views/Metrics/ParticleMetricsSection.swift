import SwiftUI

struct ParticleMetricsSection: View {
    let simulatedCount: Int
    let visibleCount: Int

    var body: some View {
        Section("Particles") {
            LabeledContent("Simulated") {
                Text(simulatedCount, format: .number.grouping(.automatic))
                    .monospacedDigit()
            }

            LabeledContent("Visible") {
                Text(visibleCount, format: .number.grouping(.automatic))
                    .monospacedDigit()
            }
        }
    }
}
