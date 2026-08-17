import SwiftUI

struct FrameMetricsSection: View {
    let metrics: RenderMetrics

    var body: some View {
        Section("Frame") {
            LabeledContent("FPS") {
                Text(
                    metrics.framesPerSecond,
                    format: .number.precision(.fractionLength(1))
                )
                .monospacedDigit()
            }

            LabeledContent("Interval") {
                Text(
                    "\(metrics.frameTimeMilliseconds, format: .number.precision(.fractionLength(2))) ms"
                )
                .monospacedDigit()
            }
        }
    }
}
