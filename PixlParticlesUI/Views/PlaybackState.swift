import Observation

@MainActor
@Observable
final class PlaybackState {
    var isPaused = true
    var isScrubbing = false
    var fraction = 0.0
    var resetID: UInt64 = 0
}
