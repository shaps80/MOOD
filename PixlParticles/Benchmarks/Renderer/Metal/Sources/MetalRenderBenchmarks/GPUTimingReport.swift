import Foundation
import PixlRenderer

struct GPUTimingReport {
    let samples: [GPUFrameTimings]

    func printRows() {
        print("Stage,Valid samples,Median ms,p95 ms")
        row("Total", \.total)
        row("Preparation", \.preparation)
        row("Diagnostics", \.diagnostics)
        row("Draw", \.draw)
        row("Vertex", \.vertex)
        row("Fragment", \.fragment)
    }

    private func row(_ label: String, _ keyPath: KeyPath<GPUFrameTimings, Double?>) {
        let values = samples.compactMap { $0[keyPath: keyPath] }.sorted()
        guard !values.isEmpty else { print("\(label),0,unavailable,unavailable"); return }
        let median = values[values.count / 2] * 1_000
        let p95 = values[min(values.count - 1, Int(ceil(Double(values.count) * 0.95)) - 1)] * 1_000
        print("\(label),\(values.count),\(String(format: "%.3f", median)),\(String(format: "%.3f", p95))")
    }
}
