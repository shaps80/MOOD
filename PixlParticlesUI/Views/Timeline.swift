import SwiftUI

struct ParticleTimeline: View {
    @Binding var isPaused: Bool
    @Binding var fraction: Double

    var body: some View {
        HStack {
            Button {
                isPaused.toggle()
            } label: {
                Image(systemName: isPaused ? "play" : "pause")
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
    @Previewable @State var isPaused: Bool = true
    @Previewable @State var fraction: Double = 0

    ParticleTimeline(
        isPaused: $isPaused,
        fraction: $fraction
    )
}
