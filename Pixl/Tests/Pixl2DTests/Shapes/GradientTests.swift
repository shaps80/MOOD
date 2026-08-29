import PixlGraphics
import Testing

@Suite("Gradient")
struct GradientTests {
    @Test
    func colorsAreEvenlyDistributed() {
        let gradient = Gradient(colors: [.red, .green, .blue])

        #expect(gradient.stops.map(\.location) == [0, 0.5, 1])
    }

    @Test
    func explicitStopsAreStableSorted() {
        let gradient = Gradient(stops: [
            .init(color: .blue, location: 1),
            .init(color: .red, location: 0.5),
            .init(color: .green, location: 0.5),
        ])

        #expect(gradient.stops.map(\.color) == [.red, .green, .blue])
    }
}
