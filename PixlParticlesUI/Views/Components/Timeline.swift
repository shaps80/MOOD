import SwiftUI

struct ParticleTimeline: View {
    @Bindable var playback: PlaybackState
    @Binding var playMode: PlayMode
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
                    playback.isPaused ? "Play" : "Pause",
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

            Slider(value: $playback.fraction, in: 0...1) { isEditing in
                playback.isScrubbing = isEditing
            }
            .tint(.primary)
            .sliderThumbVisibility(.hidden)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .capsule)
        .scenePadding()
        .animation(.smooth.speed(2), value: playMode)
    }

    private var playbackSystemImage: String {
        if !playback.isPaused { return "pause" }
        return playMode == .loop ? "repeat" : "play"
    }
}
