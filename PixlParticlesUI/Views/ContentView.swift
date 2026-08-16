import SwiftUI
import PixlParticles
import PixlRenderer

struct ContentView: View {
    @State private var isPaused: Bool = false
    @State private var fraction: Double = 0
    @State private var isScrubbing: Bool = false
    @State private var cameraPreset = CameraPreset.perspective

    @SceneStorage("camera.perspective.yaw")
    private var perspectiveYaw = Double(CameraPreset.perspectiveOrbit.yaw)

    @SceneStorage("camera.perspective.pitch")
    private var perspectivePitch = Double(CameraPreset.perspectiveOrbit.pitch)

    @SceneStorage("camera.zoom") private var cameraZoom: Double = 1

    @State private var system: System
    @State private var seed: Double
    @State private var particleCount: Double
    @State private var duration: Double
    @State private var spawnPreset: SpawnPreset
    @State private var spawnDomain: SpawnRegion.Domain
    @State private var lodEnabled = true
    @State private var lodActivation = 500_000.0
    @State private var lodMaximum = 1_000_000.0
    @State private var lodTileSize = 16.0
    @State private var lodPointsPerPixel = 1.0

    init() {
        _seed = .init(initialValue: 0)
        _particleCount = .init(initialValue: 1_000_000)
        _duration = .init(initialValue: 20)
        _spawnPreset = .init(initialValue: .sphere)
        _spawnDomain = .init(initialValue: .surface)

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
        ZStack(alignment: .topTrailing) {
            ParticleViewport(
                system: system,
                isPaused: isPaused,
                isScrubbing: isScrubbing,
                cameraPreset: cameraPreset,
                perspectiveYaw: $perspectiveYaw,
                perspectivePitch: $perspectivePitch,
                cameraZoom: $cameraZoom,
                fraction: $fraction,
                pointLOD: pointLOD
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer(minLength: 0)

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
                        lodPointsPerPixel: $lodPointsPerPixel
                    )
                    .scenePadding([.horizontal, .vertical])
                }

                Spacer(minLength: 0)

                ParticleTimeline(
                    fraction: $fraction,
                    isScrubbing: $isScrubbing
                )
                .frame(maxWidth: 500)
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
            ToolbarItem(placement: .principal) {
                Picker("Camera", selection: $cameraPreset) {
                    Text("Perspective").tag(CameraPreset.perspective)
                    Text("Isometric").tag(CameraPreset.isometric)
                    Text("Front").tag(CameraPreset.front)
                }
                .pickerStyle(.segmented)
            }

            ToolbarItem {
                Button(
                    isPaused ? "Play" : "Pause",
                    systemImage: isPaused ? "play" : "pause"
                ) {
                    isPaused.toggle()
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

}

#Preview {
    ContentView()
}
