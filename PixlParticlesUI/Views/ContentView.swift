import SwiftUI
import PixlParticles

struct ContentView: View {
    @State private var system: System = .init()
    @State private var fraction: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation) { _ in
                let now = ContinuousClock.now

                Canvas { context, size in
                    for particle in system.sample(at: now) {
                        guard let symbol = context.resolveSymbol(id: "particle") else { continue }

                        // center just for testing
                        let x: Double = (size.width - .init(particle.position.x)) / 2
                        let y: Double = (size.height - .init(particle.position.y)) / 2

                        context.draw(symbol, at: .init(x: x, y: y))
                    }
                } symbols: {
                    Rectangle()
                        .frame(width: 2, height: 2)
                        .foregroundStyle(.gray)
                        .tag("particle")
                }
            }

            Divider()

            Slider(value: $fraction, in: 0...1)
                .sliderThumbVisibility(.hidden)
                .scenePadding()
                .background(.quinary)
        }
    }
}

#Preview {
    ContentView()
}
