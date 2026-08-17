import SwiftUI

struct GPUMetricsSection: View {
    let metrics: RenderMetrics

    var body: some View {
        Section("GPU") {
            LabeledContent("Time") {
                Text(
                    "\(metrics.gpuMilliseconds, format: .number.precision(.fractionLength(2))) ms"
                )
                .monospacedDigit()
            }
        }
    }
}
