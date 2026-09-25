import PixlProfilerUI
import Combine

@MainActor
final class EditorProfiler: ObservableObject {
    let recording = EditorRecording()
    var controller: ProfileController { recording.controller }

    func update(isVisible: Bool, isPaused: Bool) {
        if isPaused || !isVisible { controller.freeze() }
        else { controller.resume() }
    }
}
