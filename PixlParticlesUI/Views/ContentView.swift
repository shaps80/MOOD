import PixlEditorSupport
import PixlParticles
import PixlRenderer
import SwiftUI

struct ContentView: View {
    @Environment(\.undoManager) private var undoManager
    @Bindable var document: ParticleDocument
    @SceneStorage("editor.settings") private var settings = EditorSettings()

    @State private var system: System
    @State private var playback = PlaybackState()
    @State private var metrics = RenderMetrics()

    init(document: ParticleDocument) {
        self.document = document
        
        let snapshot = document.snapshot
        _system = .init(
            initialValue: .init(
                seed: UInt64(snapshot.seed),
                emitter: Self.emitter(from: snapshot),
                duration: .seconds(snapshot.duration),
                storesRewindState: false
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ParticleViewport(
                    system: system,
                    playback: playback,
                    duration: .seconds(document.snapshot.duration),
                    camera: $settings.camera,
                    observerCamera: $settings.observerCamera,
                    renderer: document.snapshot.renderer,
                    renderValues: renderValues,
                    pointLOD: pointLOD,
                    isGroundPlaneVisible: settings.visibility.isGroundPlaneVisible,
                    isFrustumVisible: settings.visibility.isFrustumVisible,
                    cullingBounds: cullingBounds,
                    capturesDiagnostics: settings.visibility.isDataVisible,
                    metrics: metrics,
                    onPlaybackComplete: completePlayback
                )
                .ignoresSafeArea()
                .draggableInspector(
                    isPresented: $settings.visibility.isInspectorVisible
                ) {
                    EditorInspector(
                        document: document,
                        system: $system,
                        playback: $playback
                    )
                    .animation(.smooth.speed(2), value: document.snapshot)
                }
                .draggableInspector(
                    id: "data",
                    placement: .bottomLeading,
                    isPresented: $settings.visibility.isDataVisible
                ) {
                    DataInspector(
                        simulatedCount: Int(document.snapshot.particleCount),
                        metrics: metrics
                    )
                }

                VStack {
                    Spacer(minLength: 0)

                    ParticleTimeline(
                        playback: playback,
                        playMode: $settings.playMode,
                        togglePlayback: togglePlayback
                    )
                    .frame(maxWidth: 500)
                }
                .ignoresSafeArea()
            }
            .background(.quinary)
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Picker("Camera", selection: $settings.camera.preset) {
                        Text("Perspective").tag(CameraPreset.perspective)
                        Text("Isometric").tag(CameraPreset.isometric)
                        Text("Front").tag(CameraPreset.front)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
#if os(iOS)
                .sharedBackgroundVisibility(.hidden)
#endif

                ToolbarItem(placement: .primaryAction) {
                    Menu("View", systemImage: "ellipsis") {
                        Toggle(
                            "Ground Plane",
                            isOn: $settings.visibility.isGroundPlaneVisible
                        )

                        Section("Inspectors") {
                            Toggle(
                                "Properties",
                                isOn: $settings.visibility.isInspectorVisible
                            )
                            Toggle(
                                "Metrics",
                                isOn: $settings.visibility.isDataVisible
                            )
                        }

                        Section("Debugging") {
                            Toggle(
                                "Culling Bounds",
                                isOn: $settings.visibility.isCullingVisible
                            )
                            Toggle(
                                "Camera Frustum",
                                isOn: $settings.visibility.isFrustumVisible
                            )
                            .disabled(settings.camera.preset != .perspective)
                        }
                    }
                }

                ToolbarSpacer(.fixed, placement: .primaryAction)

                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Undo", systemImage: "arrow.uturn.backward") {
                        undoManager?.undo()
                    }
                    .disabled(!(undoManager?.canUndo ?? false))

                    Button("Redo", systemImage: "arrow.uturn.forward") {
                        undoManager?.redo()
                    }
                }
            }
        }
    }

    private var pointLOD: PointLOD {
        let snapshot = document.snapshot
        return .init(
            isEnabled: snapshot.isLODEnabled,
            activationCount: max(Int(snapshot.lodActivation), 0),
            maximumVisibleCount: max(Int(snapshot.lodMaximum), 1),
            tileSize: max(Int(snapshot.lodTileSize), 1),
            targetPointsPerPixel: max(Float(snapshot.lodPointsPerPixel), 0.001)
        )
    }

    private var renderValues: ParticleRenderValues {
        let snapshot = document.snapshot
        return .init(
            size: [
                max(Float(snapshot.billboardWidth), 0),
                max(Float(snapshot.billboardHeight), 0),
            ],
            rotation: Float(snapshot.billboardRotation)
        )
    }

    private var cullingBounds: CullingBounds {
        let snapshot = document.snapshot
        return .init(
            isEnabled: snapshot.isCullingEnabled,
            isVisible: settings.visibility.isCullingVisible,
            scale: Float(snapshot.cullingBoundsScale)
        )
    }

    private func completePlayback() {
        if settings.playMode == .loop {
            playback.resetID &+= 1
        } else {
            playback.isPaused = true
        }
    }

    private func togglePlayback() {
        if playback.isPaused, playback.fraction >= 1 {
            playback.fraction = 0
            playback.resetID &+= 1
        }
        playback.isPaused.toggle()
    }

    private func binding<Value>(
        _ keyPath: WritableKeyPath<ParticleDocument.Snapshot, Value>,
        _ actionName: String
    ) -> Binding<Value> {
        document.binding(
            keyPath,
            actionName: actionName,
            undoManager: undoManager
        )
    }

    private func edit(
        _ actionName: String,
        _ edit: (inout ParticleDocument.Snapshot) -> Void
    ) {
        document.performEdit(
            actionName: actionName,
            undoManager: undoManager,
            edit
        )
    }

    private static func emitter(
        from snapshot: ParticleDocument.Snapshot
    ) -> Emitter {
        var emitter = EmitterPreset.debris.emitter(
            capacity: Int(snapshot.particleCount)
        )
        emitter.spawnRegion = snapshot.spawnPreset.region(
            domain: snapshot.spawnDomain
        )
        emitter[\.color] = .init([.set(snapshot.color)])
        emitter[\.size] = .init([
            .set([
                max(Float(snapshot.billboardWidth), 0),
                max(Float(snapshot.billboardHeight), 0),
            ]),
        ])
        emitter[\.rotation] = .init([
            .set(Float(snapshot.billboardRotation)),
        ])
        emitter.renderers = [snapshot.renderer]
        return emitter
    }
}

#Preview {
    ContentView(document: ParticleDocument())
}
