import PixlRenderer

/// Missing counter samples never contribute zero to a rolling average.
struct GPUTimingSums {
    private var total = Sum()
    private var preparation = Sum()
    private var diagnostics = Sum()
    private var draw = Sum()
    private var vertex = Sum()
    private var fragment = Sum()

    mutating func add(_ sample: GPUFrameTimings, sign: Int = 1) {
        total.add(sample.total, sign: sign)
        preparation.add(sample.preparation, sign: sign)
        diagnostics.add(sample.diagnostics, sign: sign)
        draw.add(sample.draw, sign: sign)
        vertex.add(sample.vertex, sign: sign)
        fragment.add(sample.fragment, sign: sign)
    }

    var average: GPUFrameTimings {
        .init(total: total.average, preparation: preparation.average,
              diagnostics: diagnostics.average, draw: draw.average,
              vertex: vertex.average, fragment: fragment.average)
    }

    private struct Sum {
        var value = 0.0
        var count = 0
        mutating func add(_ sample: Double?, sign: Int) {
            guard let sample else { return }
            value += sample * Double(sign)
            count += sign
            if count == 0 { value = 0 }
        }
        var average: Double? { count > 0 ? value / Double(count) : nil }
    }
}
