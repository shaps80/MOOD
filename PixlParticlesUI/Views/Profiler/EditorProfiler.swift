import PixlProfilerUI
import Combine

@MainActor
final class EditorProfiler: ObservableObject {
    let recording = EditorRecording()
    var controller: ProfileController { recording.controller }
    @Published var isVisible = false

    func update(isPaused: Bool) {
        if isPaused || !isVisible { controller.freeze() }
        else { controller.resume() }
    }
}
