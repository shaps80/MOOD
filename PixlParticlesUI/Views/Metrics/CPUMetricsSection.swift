import SwiftUI

struct CPUMetricsSection: View {
    let metrics: RenderMetrics

    var body: some View {
        Section("CPU") {
            LabeledContent("Simulation") {
                Text(
                    "\(metrics.cpuSimulationMilliseconds, format: .number.precision(.fractionLength(2))) ms"
                )
                .monospacedDigit()
            }

            LabeledContent("Render") {
                Text(
                    "\(metrics.cpuRenderMilliseconds, format: .number.precision(.fractionLength(2))) ms"
                )
                .monospacedDigit()
            }
        }
    }
}
