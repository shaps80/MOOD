import SwiftUI

struct ParticleTimeline: View {
    @Binding var isPlaying: Bool
    @Binding var fraction: Double

    var body: some View {
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

#Preview {
    @Previewable @State var isPlaying: Bool = false
    @Previewable @State var fraction: Double = 0

    ParticleTimeline(
        isPlaying: $isPlaying,
        fraction: $fraction
    )
}
