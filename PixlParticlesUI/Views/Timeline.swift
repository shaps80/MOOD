import SwiftUI

struct ParticleTimeline: View {
    @Binding var fraction: Double
    @Binding var isScrubbing: Bool

    var body: some View {
        Slider(value: $fraction, in: 0...1) { isEditing in
            isScrubbing = isEditing
        }
        .sliderThumbVisibility(.hidden)
        .padding(.horizontal)
        .glassEffect(.clear, in: .capsule)
        .scenePadding()
    }
}

#Preview {
    @Previewable @State var fraction: Double = 0

    ParticleTimeline(
        fraction: $fraction,
        isScrubbing: .constant(false)
    )
}
