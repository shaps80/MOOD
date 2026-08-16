import SwiftUI

struct ParticleTimeline: View {
    @Binding var fraction: Double
    @Binding var isScrubbing: Bool

    var body: some View {
        Slider(value: $fraction, in: 0...1) { isEditing in
            isScrubbing = isEditing
        }
        .tint(.primary)
        .background {
            HStack {
                Button("Back") {
                    fraction -= 0.1
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button("Forward") {
                    fraction += 0.1
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
            }
            .hidden()
        }
        .sliderThumbVisibility(.hidden)
        .padding(.horizontal, 10)
        .background(.bar, in: .capsule)
        .scenePadding()
    }
}
