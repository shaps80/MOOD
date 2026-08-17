import PixlParticles
import PixlRenderer
import SwiftUI
import simd

struct ContentView: View {
    @Environment(\.undoManager) private var undoManager
    @Bindable var document: ParticleDocument
    @State private var isPaused: Bool = true
    @State private var fraction: Double = 0
    @State private var isScrubbing: Bool = false
    @SceneStorage("editor.settings") private var settings = EditorSettings()

    @State private var system: System
    @State private var playbackResetID: UInt64 = 0

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
                    isPaused: isPaused,
                    isScrubbing: isScrubbing,
                    duration: .seconds(document.snapshot.duration),
                    camera: $settings.camera,
                    fraction: $fraction,
                    pointLOD: pointLOD,
                    isGroundPlaneVisible: settings.visibility.isGroundPlaneVisible,
                    cullingBounds: cullingBounds,
                    playbackResetID: playbackResetID,
                    onPlaybackComplete: completePlayback
                )
                .ignoresSafeArea()
                .overlay {
                    MovableOverlay(
                        horizontalPosition: $settings.inspector.horizontalPosition,
                        verticalPosition: $settings.inspector.verticalPosition,
                        isVisible: settings.visibility.isInspectorVisible
                    ) {
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
                            areCullingBoundsVisible: settings.visibility.areCullingBoundsVisible,
                            areCullingBoundsEnabled: binding(
                                \.areCullingBoundsEnabled, "Toggle Culling Bounds"),
                            cullingBoundsScale: binding(\.cullingBoundsScale, "Change Culling Bounds")
                        )
                    }
                    .scenePadding()
                }

                VStack {
                    Spacer(minLength: 0)

                    ParticleTimeline(
                        fraction: $fraction,
                        isScrubbing: $isScrubbing,
                        isPaused: isPaused,
                        playMode: $settings.playMode,
                        playbackSystemImage: playbackSystemImage,
                        togglePlayback: togglePlayback
                    )
                    .frame(maxWidth: 500)
                }
                .ignoresSafeArea()
            }
            .background(.quinary)
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
                        Toggle(
                            "Inspector",
                            isOn: $settings.visibility.isInspectorVisible
                        )

                        Toggle(
                            "Culling Bounds",
                            isOn: $settings.visibility.areCullingBoundsVisible
                        )
                    }
                }

                ToolbarSpacer(.fixed, placement: .primaryAction)

                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Undo", systemImage: "arrow.uturn.backward") {
                        undoManager?.undo()
                    }
                    .disabled(!(undoManager?.canUndo ?? false))
                    .keyboardShortcut("z", modifiers: .command)

                    Button("Redo", systemImage: "arrow.uturn.forward") {
                        undoManager?.redo()
                    }
                    .disabled(!(undoManager?.canRedo ?? false))
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                }
            }
        }
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
        fraction = 0
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
            isEnabled: snapshot.areCullingBoundsEnabled,
            isVisible: settings.visibility.areCullingBoundsVisible,
            scale: Float(snapshot.cullingBoundsScale)
        )
    }

    private func completePlayback() {
        if settings.playMode == .loop {
            playbackResetID &+= 1
        } else {
            isPaused = true
        }
    }

    private func togglePlayback() {
        if isPaused, fraction >= 1 {
            fraction = 0
            playbackResetID &+= 1
        }
        isPaused.toggle()
    }

    private var playbackSystemImage: String {
        if !isPaused { return "pause" }
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
