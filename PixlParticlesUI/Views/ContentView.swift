import SwiftUI
import PixlParticles

struct ContentView: View {
    @State private var isPlaying: Bool = false
    @State private var system: System = .init()
    @State private var fraction: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation) { _ in
                let now = ContinuousClock.now

                Canvas { context, size in
                    guard let symbol = context.resolveSymbol(id: "particle") else { return }
                    let sample = system.sample(
                        at: now,
                        isPaused: !isPlaying
                    )

                    for particle in sample.particles {
                        let position = particle.interpolated(by: sample.interpolation)
                        // center just for testing
                        let x: Double = size.width / 2 + .init(position.x)
                        let y: Double = size.height / 2 + .init(position.y)

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

            HStack {
                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause" : "play")
                        .symbolVariant(.fill)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                }
                .buttonStyle(.glass)
                .toggleStyle(.button)

                Slider(value: $fraction, in: 0...1)
                    .sliderThumbVisibility(.hidden)
            }
            .scenePadding()
            .background(.quinary)
        }
    }
}

#Preview {
    ContentView()
}
