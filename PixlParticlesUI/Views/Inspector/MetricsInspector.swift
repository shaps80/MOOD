import SwiftUI

struct MetricsInspector: View {
    let simulatedCount: Int
    let metrics: RenderMetrics

    var body: some View {
        Inspector {
            ParticleMetricsSection(
                simulatedCount: simulatedCount,
                visibleCount: metrics.visibleCount
            )
            FrameMetricsSection(metrics: metrics)
            CPUMetricsSection(metrics: metrics)
            GPUMetricsSection(metrics: metrics)
        }
    }
}
