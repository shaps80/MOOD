import PixlRenderer
import SwiftUI

struct GPUMetricsSection: View {
    let metrics: RenderMetrics

    var body: some View {
        Section("GPU") {
            timing("Total", seconds: metrics.gpuTimings.total)
            timing("Preparation", seconds: metrics.gpuTimings.preparation)
            timing("Diagnostics", seconds: metrics.gpuTimings.diagnostics)
            timing("Draw", seconds: metrics.gpuTimings.draw)
            timing("Vertex", seconds: metrics.gpuTimings.vertex)
            timing("Fragment", seconds: metrics.gpuTimings.fragment)
        }
    }

    private func timing(_ title: String, seconds: Double?) -> some View {
        LabeledContent(title) {
            if let seconds {
                Text("\(seconds * 1_000, format: .number.precision(.fractionLength(2))) ms")
                    .monospacedDigit()
            } else {
                Text("—")
            }
        }
    }
}
