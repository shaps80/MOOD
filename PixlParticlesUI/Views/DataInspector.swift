import SwiftUI

struct DataInspector: View {
    let simulatedCount: Int
    let metrics: RenderMetrics

    var body: some View {
        Divided {
            ParticleMetricsSection(
                simulatedCount: simulatedCount,
                visibleCount: metrics.visibleCount
            )
            FrameMetricsSection(metrics: metrics)
            CPUMetricsSection(metrics: metrics)
            GPUMetricsSection(metrics: metrics)
        }
        .frame(minWidth: 180, alignment: .topLeading)
        .scenePadding()
        .padding(5)
        .labeledContentStyle(.inspector)
        .focusable(false)
        .focusEffectDisabled(true)
        .clipShape(.rect(cornerRadius: 28))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
        .frame(maxWidth: 250)
    }
}
