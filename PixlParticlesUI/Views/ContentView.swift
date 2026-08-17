import PixlParticles
import PixlRenderer
import SwiftUI
import simd

struct ContentView: View {
    @Environment(\.undoManager) private var undoManager
    @Bindable var document: ParticleDocument
    @State private var commands = ParticleCommandTarget()
    @State private var isScrubbing: Bool = false
    @SceneStorage("editor.settings") private var settings = EditorSettings()

    @State private var system: System
    init(document: ParticleDocument) {
        self.document = document
        let snapshot = document.snapshot
        _system = .init(
            initialValue: .init(
                seed: UInt64(snapshot.seed),
                particleCount: Int(snapshot.particleCount),
                spawnRegion: snapshot.spawnPreset.region(
                    domain: snapshot.spawnDomain
                ),
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
                    isPaused: commands.isPaused,
                    isScrubbing: isScrubbing,
                    duration: .seconds(document.snapshot.duration),
                    camera: $settings.camera,
                    fraction: $commands.fraction,
                    pointLOD: pointLOD,
                    isGroundPlaneVisible: settings.visibility.isGroundPlaneVisible,
                    cullingBounds: cullingBounds,
                    playbackResetID: commands.playbackResetID,
                    onPlaybackComplete: completePlayback
                )
                .ignoresSafeArea()
                .draggableInspector(isPresented: $commands.isInspectorVisible) {
                    Inspector(
                        duration: binding(\.duration, "Change Duration"),
                        particleCount: binding(\.particleCount, "Change Particle Count"),
                        seed: binding(\.seed, "Change Seed"),
                        spawnPreset: binding(\.spawnPreset, "Change Spawn Region"),
                        spawnDomain: binding(\.spawnDomain, "Change Spawn Domain"),
                        lodEnabled: binding(\.isLODEnabled, "Toggle LOD"),
                        lodActivation: binding(\.lodActivation, "Change LOD Activation"),
                        lodMaximum: binding(\.lodMaximum, "Change LOD Maximum"),
                        lodTileSize: binding(\.lodTileSize, "Change LOD Tile Size"),
                        lodPointsPerPixel: binding(\.lodPointsPerPixel, "Change LOD Density"),
                        isCullingEnabled: binding(
                            \.isCullingEnabled, "Toggle Culling Bounds"),
                        cullingBoundsScale: binding(\.cullingBoundsScale, "Change Culling Bounds")
                    )
                }

                VStack {
                    Spacer(minLength: 0)

                    ParticleTimeline(
                        fraction: $commands.fraction,
                        isScrubbing: $isScrubbing,
                        isPaused: commands.isPaused,
                        playMode: $settings.playMode,
                        playbackSystemImage: playbackSystemImage,
                        togglePlayback: commands.togglePlayback
                    )
                    .frame(maxWidth: 500)
                }
                .ignoresSafeArea()
            }
            .background(.quinary)
            .onAppear {
                commands.isInspectorVisible = settings.visibility.isInspectorVisible
                commands.cameraPreset = settings.camera.preset
                commands.undoManager = undoManager
            }
            .onChange(of: commands.isInspectorVisible) { _, isVisible in
                settings.visibility.isInspectorVisible = isVisible
            }
            .onChange(of: commands.cameraPreset) { _, preset in
                settings.camera.preset = preset
            }
            .onChange(of: document.snapshot.duration) { _, duration in
                let duration = max(duration, 0)

                if document.snapshot.duration != duration {
                    edit("Change Duration") { $0.duration = duration }
                }
            }
            .onChange(of: document.snapshot.particleCount) { _, particleCount in
                let particleCount = max(particleCount.rounded(), 0)

                if document.snapshot.particleCount != particleCount {
                    edit("Change Particle Count") { $0.particleCount = particleCount }
                } else {
                    updateSystem()
                }
            }
            .onChange(of: document.snapshot.seed) { _, seed in
                let maximumExactInteger = 9_007_199_254_740_991.0
                let seed = min(max(seed.rounded(), 0), maximumExactInteger)

                if document.snapshot.seed != seed {
                    edit("Change Seed") { $0.seed = seed }
                } else {
                    updateSystem()
                }
            }
            .onChange(of: document.snapshot.spawnPreset) {
                updateSystem()
            }
            .onChange(of: document.snapshot.spawnDomain) {
                updateSystem()
            }
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Picker("Camera", selection: $commands.cameraPreset) {
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
                        Toggle(
                            "Inspector",
                            isOn: $commands.isInspectorVisible
                        )

                        Toggle(
                            "Culling Bounds",
                            isOn: $settings.visibility.isCullingVisible
                        )
                    }
                }

                ToolbarSpacer(.fixed, placement: .primaryAction)

                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Undo", systemImage: "arrow.uturn.backward") {
                        commands.undo()
                    }
                    .disabled(!commands.canUndo)

                    Button("Redo", systemImage: "arrow.uturn.forward") {
                        commands.redo()
                    }
                    .disabled(!commands.canRedo)
                }
            }
        }
        .focusedValue(\.particleCommandTarget, commands)
    }

    private func updateSystem() {
        let snapshot = document.snapshot
        system = System(
            seed: UInt64(snapshot.seed),
            particleCount: Int(snapshot.particleCount),
            spawnRegion: snapshot.spawnPreset.region(domain: snapshot.spawnDomain),
            duration: .seconds(snapshot.duration),
            storesRewindState: false
        )
        commands.fraction = 0
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

    private var cullingBounds: CullingBounds {
        let snapshot = document.snapshot
        return .init(
            isEnabled: snapshot.isCullingEnabled,
            isVisible: settings.visibility.isCullingVisible,
            scale: Float(snapshot.cullingBoundsScale)
        )
    }

    private func completePlayback() {
        commands.completePlayback(for: settings.playMode)
    }

    private var playbackSystemImage: String {
        if !commands.isPaused { return "pause" }
        return settings.playMode == .loop ? "repeat" : "play"
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
}

#Preview {
    ContentView(document: ParticleDocument())
}
