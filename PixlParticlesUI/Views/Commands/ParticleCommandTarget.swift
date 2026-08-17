import Observation
import SwiftUI

@MainActor
@Observable
final class ParticleCommandTarget {
    var isPaused = true
    var fraction = 0.0
    var playbackResetID: UInt64 = 0
    var isInspectorVisible = true
    var cameraPreset = CameraPreset.perspective
    var undoManager: UndoManager?

    var canUndo: Bool {
        undoManager?.canUndo ?? false
    }

    var canRedo: Bool {
        undoManager?.canRedo ?? false
    }

    func togglePlayback() {
        if isPaused, fraction >= 1 {
            fraction = 0
            playbackResetID &+= 1
        }
        isPaused.toggle()
    }

    func completePlayback(for playMode: PlayMode) {
        if playMode == .loop {
            playbackResetID &+= 1
        } else {
            isPaused = true
        }
    }

    func undo() {
        undoManager?.undo()
    }

    func redo() {
        undoManager?.redo()
    }
}

extension FocusedValues {
    @Entry var particleCommandTarget: ParticleCommandTarget?
}
