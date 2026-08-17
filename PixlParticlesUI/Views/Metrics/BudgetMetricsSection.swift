import SwiftUI

struct BudgetMetricsSection: View {
    let metrics: RenderMetrics

    var body: some View {
        Section("Budgets") {
            LabeledContent("CPU") {
                Text(
                    metrics.cpuBudget,
                    format: .percent.precision(.fractionLength(1))
                )
                .monospacedDigit()
            }

            LabeledContent("GPU") {
                Text(
                    metrics.gpuBudget,
                    format: .percent.precision(.fractionLength(1))
                )
                .monospacedDigit()
            }

            LabeledContent("Combined") {
                Text(
                    metrics.combinedBudget,
                    format: .percent.precision(.fractionLength(1))
                )
                .monospacedDigit()
            }
        }
    }
}
