import SwiftUI

struct ParticleCommands: Commands {
    @FocusedValue(\.particleCommandTarget) private var target

    var body: some Commands {
        CommandMenu("Editor") {
            Section("Camera") {
                Button("Perspective") {
                    target?.cameraPreset = .perspective
                }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(target == nil)

                Button("Isometric") {
                    target?.cameraPreset = .isometric
                }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(target == nil)

                Button("Front") {
                    target?.cameraPreset = .front
                }
                .keyboardShortcut("3", modifiers: .command)
                .disabled(target == nil)
            }

            Button("Toggle Playback") {
                target?.togglePlayback()
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(target == nil)
        }

        CommandGroup(replacing: .sidebar) {
            Toggle("Inspector", isOn: inspectorVisibility)
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(target == nil)
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                target?.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!(target?.canUndo ?? false))

            Button("Redo") {
                target?.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!(target?.canRedo ?? false))
        }
    }

    private var inspectorVisibility: Binding<Bool> {
        .init(
            get: { target?.isInspectorVisible ?? false },
            set: { target?.isInspectorVisible = $0 }
        )
    }
}
