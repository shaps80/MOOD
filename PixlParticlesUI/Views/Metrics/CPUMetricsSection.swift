import SwiftUI

struct CPUMetricsSection: View {
    let metrics: RenderMetrics

    var body: some View {
        Section("CPU") {
            LabeledContent("Simulation") {
                Text(
                    "\(metrics.cpuSimulationMilliseconds, format: .number.precision(.fractionLength(simulationFractionDigits))) ms"
                )
                .monospacedDigit()
            }

            LabeledContent("Render") {
                Text(
                    "\(metrics.cpuRenderMilliseconds, format: .number.precision(.fractionLength(2))) ms"
                )
                .monospacedDigit()
            }

            LabeledContent("Budget") {
                Text(
                    metrics.cpuBudget,
                    format: .percent.precision(.fractionLength(1))
                )
                .monospacedDigit()
            }
        }
    }

    private var simulationFractionDigits: Int {
        metrics.cpuSimulationMilliseconds.magnitude < 0.01 ? 3 : 2
    }
}
