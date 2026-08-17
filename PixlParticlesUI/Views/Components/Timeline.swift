import SwiftUI

struct ParticleTimeline: View {
    @Binding var fraction: Double
    @Binding var isScrubbing: Bool
    let isPaused: Bool
    @Binding var playMode: PlayMode
    let playbackSystemImage: String
    let togglePlayback: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Menu {
                Picker("Playback", selection: $playMode) {
                    ForEach(PlayMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(
                    isPaused ? "Play" : "Pause",
                    systemImage: playbackSystemImage
                )
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(.foreground)
            } primaryAction: {
                togglePlayback()
            }
            .symbolVariant(.fill)
            .buttonStyle(.plain)

            Slider(value: $fraction, in: 0...1) { isEditing in
                isScrubbing = isEditing
            }
            .tint(.primary)
            .sliderThumbVisibility(.hidden)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .capsule)
        .scenePadding()
        .animation(.bouncy, value: playMode)
    }
}
