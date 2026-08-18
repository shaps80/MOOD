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
                particleCount: Int(snapshot.particleCount),
                spawnRegion: snapshot.spawnPreset.region(
                    domain: snapshot.spawnDomain
                ),
                color: snapshot.color,
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
                    Inspector(
                        duration: binding(\.duration, "Change Duration"),
                        particleCount: binding(\.particleCount, "Change Particle Count"),
                        seed: binding(\.seed, "Change Seed"),
                        spawnPreset: binding(\.spawnPreset, "Change Spawn Region"),
                        spawnDomain: binding(\.spawnDomain, "Change Spawn Domain"),
                        renderMode: binding(\.renderer.mode, "Change Render Mode"),
                        billboardSizeSpace: binding(
                            \.renderer.billboard.sizeSpace,
                            "Change Billboard Size Space"
                        ),
                        billboardFacing: binding(
                            \.renderer.billboard.facing,
                            "Change Billboard Facing"
                        ),
                        billboardWidth: binding(
                            \.billboardWidth,
                            "Change Billboard Width"
                        ),
                        billboardHeight: binding(
                            \.billboardHeight,
                            "Change Billboard Height"
                        ),
                        billboardRotation: binding(
                            \.billboardRotation,
                            "Change Billboard Rotation"
                        ),
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
            .onChange(of: document.snapshot.color) {
                updateSystem()
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
                            "Metrics",
                            isOn: $settings.visibility.isDataVisible
                        )

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

    private func updateSystem() {
        let snapshot = document.snapshot
        system = System(
            seed: UInt64(snapshot.seed),
            particleCount: Int(snapshot.particleCount),
            spawnRegion: snapshot.spawnPreset.region(domain: snapshot.spawnDomain),
            color: snapshot.color,
            duration: .seconds(snapshot.duration),
            storesRewindState: false
        )
        playback.fraction = 0
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
}

#Preview {
    ContentView(document: ParticleDocument())
}
