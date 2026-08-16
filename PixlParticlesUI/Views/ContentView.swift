import SwiftUI
import PixlParticles
import PixlRenderer
import simd

struct ContentView: View {
    @State private var isPaused: Bool = true
    @State private var fraction: Double = 0
    @State private var isScrubbing: Bool = false
    @State private var cameraPreset = CameraPreset.perspective

    @SceneStorage("camera.perspective.rotation.x")
    private var perspectiveRotationX = Double(
        CameraPreset.perspectiveOrbit.rotation.vector.x
    )
    @SceneStorage("camera.perspective.rotation.y")
    private var perspectiveRotationY = Double(
        CameraPreset.perspectiveOrbit.rotation.vector.y
    )
    @SceneStorage("camera.perspective.rotation.z")
    private var perspectiveRotationZ = Double(
        CameraPreset.perspectiveOrbit.rotation.vector.z
    )
    @SceneStorage("camera.perspective.rotation.w")
    private var perspectiveRotationW = Double(
        CameraPreset.perspectiveOrbit.rotation.vector.w
    )

    @SceneStorage("camera.zoom") private var cameraZoom: Double = 1
    @SceneStorage("camera.perspective.target.x") private var cameraTargetX = 0.0
    @SceneStorage("camera.perspective.target.y") private var cameraTargetY = 0.0
    @SceneStorage("camera.perspective.target.z") private var cameraTargetZ = 0.0

    @State private var system: System
    @State private var seed: Double
    @State private var particleCount: Double
    @State private var duration: Double
    @State private var spawnPreset: SpawnPreset
    @State private var spawnDomain: SpawnRegion.Domain
    @State private var lodEnabled = false
    @State private var lodActivation = 500_000.0
    @State private var lodMaximum = 1_000_000.0
    @State private var lodTileSize = 16.0
    @State private var lodPointsPerPixel = 1.0
    @SceneStorage("editor.groundPlane.isVisible")
    private var isGroundPlaneVisible = true
    @SceneStorage("editor.timeline.isVisible")
    private var isTimelineVisible = true
    @SceneStorage("editor.inspector.isVisible")
    private var isInspectorVisible = true
    @SceneStorage("editor.inspector.position.x")
    private var inspectorPositionX = 1.0
    @SceneStorage("editor.inspector.position.y")
    private var inspectorPositionY = 0.0
    @SceneStorage("editor.cullingBounds.isVisible")
    private var areCullingBoundsEnabled = false
    @SceneStorage("editor.cullingBounds.scale")
    private var cullingBoundsScale = 300.0
    @SceneStorage("editor.playMode") private var playMode = PlayMode.play
    @State private var playbackResetID: UInt64 = 0

    init() {
        _seed = .init(initialValue: 0)
        _particleCount = .init(initialValue: 50_000)
        _duration = .init(initialValue: 30)
        _spawnPreset = .init(initialValue: .plane)
        _spawnDomain = .init(initialValue: .volume)

        _system = .init(
            initialValue: .init(
                seed: .init(_seed.wrappedValue),
                particleCount: .init(_particleCount.wrappedValue),
                spawnRegion: _spawnPreset.wrappedValue.region(
                    domain: _spawnDomain.wrappedValue
                ),
                duration: .seconds(_duration.wrappedValue),
                storesRewindState: false
            )
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ParticleViewport(
                system: system,
                isPaused: isPaused,
                isScrubbing: isScrubbing,
                cameraPreset: cameraPreset,
                perspectiveRotationX: $perspectiveRotationX,
                perspectiveRotationY: $perspectiveRotationY,
                perspectiveRotationZ: $perspectiveRotationZ,
                perspectiveRotationW: $perspectiveRotationW,
                cameraZoom: $cameraZoom,
                cameraTargetX: $cameraTargetX,
                cameraTargetY: $cameraTargetY,
                cameraTargetZ: $cameraTargetZ,
                fraction: $fraction,
                pointLOD: pointLOD,
                isGroundPlaneVisible: isGroundPlaneVisible,
                cullingBounds: cullingBounds,
                playbackResetID: playbackResetID,
                onPlaybackComplete: completePlayback
            )
            .ignoresSafeArea()
            .overlay {
                if isInspectorVisible {
                    MovableOverlay(
                        horizontalPosition: $inspectorPositionX,
                        verticalPosition: $inspectorPositionY
                    ) {
                        Inspector(
                            duration: $duration,
                            particleCount: $particleCount,
                            seed: $seed,
                            spawnPreset: $spawnPreset,
                            spawnDomain: $spawnDomain,
                            lodEnabled: $lodEnabled,
                            lodActivation: $lodActivation,
                            lodMaximum: $lodMaximum,
                            lodTileSize: $lodTileSize,
                            lodPointsPerPixel: $lodPointsPerPixel,
                            areCullingBoundsEnabled: $areCullingBoundsEnabled,
                            cullingBoundsScale: $cullingBoundsScale
                        )
                    }
                    .scenePadding()
                }
            }

            VStack {
                Spacer(minLength: 0)

                if isTimelineVisible {
                    ParticleTimeline(
                        fraction: $fraction,
                        isScrubbing: $isScrubbing
                    )
                    .frame(maxWidth: 500)
                }
            }
        }
        .background(.quinary)
        .onChange(of: duration) { _, duration in
            let duration = max(duration, 0)

            if self.duration != duration {
                self.duration = duration
            } else {
                updateSystem()
            }
        }
        .onChange(of: particleCount) { _, particleCount in
            let particleCount = max(particleCount.rounded(), 0)

            if self.particleCount != particleCount {
                self.particleCount = particleCount
            } else {
                updateSystem()
            }
        }
        .onChange(of: seed) { _, seed in
            let maximumExactInteger = 9_007_199_254_740_991.0
            let seed = min(max(seed.rounded(), 0), maximumExactInteger)

            if self.seed != seed {
                self.seed = seed
            } else {
                updateSystem()
            }
        }
        .onChange(of: spawnPreset) {
            updateSystem()
        }
        .onChange(of: spawnDomain) {
            updateSystem()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Menu("View", systemImage: "slider.vertical.3") {
                    Toggle("Ground Plane", isOn: $isGroundPlaneVisible)
                    Toggle("Inspector", isOn: $isInspectorVisible)
                    Toggle("Timeline", isOn: $isTimelineVisible)
                    Toggle(
                        "Culling Bounds",
                        isOn: $areCullingBoundsEnabled
                    )
                }
            }

            ToolbarItem(placement: .principal) {
                Picker("Camera", selection: $cameraPreset) {
                    Text("Perspective").tag(CameraPreset.perspective)
                    Text("Isometric").tag(CameraPreset.isometric)
                    Text("Front").tag(CameraPreset.front)
                }
                .pickerStyle(.segmented)
            }

            ToolbarItem {
                Menu {
                    Picker("Playback", selection: $playMode) {
                        ForEach(PlayMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(
                        isPaused ? "Play" : "Pause",
                        systemImage: isPaused ? "play" : "pause"
                    )
                } primaryAction: {
                    togglePlayback()
                }
                .symbolVariant(.fill)
                .keyboardShortcut(.space, modifiers: [])
            }
        }
    }

    private func updateSystem() {
        system = System(
            seed: UInt64(seed),
            particleCount: Int(particleCount),
            spawnRegion: spawnPreset.region(domain: spawnDomain),
            duration: .seconds(duration),
            storesRewindState: false
        )
        fraction = 0
    }

    private var pointLOD: PointLOD {
        .init(
            isEnabled: lodEnabled,
            activationCount: max(Int(lodActivation), 0),
            maximumVisibleCount: max(Int(lodMaximum), 1),
            tileSize: max(Int(lodTileSize), 1),
            targetPointsPerPixel: max(Float(lodPointsPerPixel), 0.001)
        )
    }

    private var cullingBounds: CullingBounds {
        .init(
            isEnabled: areCullingBoundsEnabled,
            scale: Float(cullingBoundsScale)
        )
    }

    private func completePlayback() {
        if playMode == .loop {
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
}

#Preview {
    ContentView()
}
