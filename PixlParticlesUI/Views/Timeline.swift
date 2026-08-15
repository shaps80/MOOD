import SwiftUI

struct ParticleTimeline: View {
    @Binding var fraction: Double

    var body: some View {
        HStack {
            Slider(value: $fraction, in: 0...1)
                .sliderThumbVisibility(.hidden)
        }
        .scenePadding()
        .background(.quinary)
    }
}

#Preview {
    @Previewable @State var fraction: Double = 0

    ParticleTimeline(
        fraction: $fraction
    )
}
