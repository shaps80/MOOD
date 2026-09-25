import PixlProfilerUI
import Combine

@MainActor
final class EditorProfiler: ObservableObject {
    let recording = EditorRecording()
    var controller: ProfileController { recording.controller }

    func update(isVisible: Bool, isPaused: Bool) {
        recording.isVisible = isVisible
        if !isVisible { controller.suspend() }
        else if isPaused { controller.freeze() }
        else { controller.resume() }
    }
}
