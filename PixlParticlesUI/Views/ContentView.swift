import SwiftUI
import PixlParticles

struct ContentView: View {
    private let orbitSensitivity: Float = 0.005
    private let scrollZoomSensitivity: Float = 0.01
    private let zoomRange: ClosedRange<Float> = 0.1...10

    @State private var isPaused: Bool = true
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

    @GestureState private var orbitTranslation: CGSize = .zero
    @GestureState private var zoomMagnification: CGFloat = 1

    private var perspectiveOrbit: Orbit {
        var orbit = CameraPreset.perspectiveOrbit
        orbit.yaw = Float(perspectiveYaw)
        orbit.pitch = Float(perspectivePitch)
        return orbit
    }

    private var camera: Camera {
        let zoom = Float(cameraZoom) * Float(zoomMagnification)

        guard cameraPreset == .perspective else {
            var camera = cameraPreset.fixedCamera
            camera.projection = camera.projection.magnified(by: zoom)
            return camera
        }

        return perspectiveOrbit.camera(
            yawOffset: -Float(orbitTranslation.width) * orbitSensitivity,
            pitchOffset: Float(orbitTranslation.height) * orbitSensitivity,
            zoom: zoom
        )
    }

    init() {
        _seed = .init(initialValue: 0)
        _particleCount = .init(initialValue: 2000)
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
                duration: .seconds(_duration.wrappedValue)
            )
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TimelineView(.animation) { _ in
                let now = ContinuousClock.now
                let sample = system.sample(
                    at: now,
                    isPaused: isPaused || isScrubbing
                )

                ParticleCanvas(
                    sample: sample,
                    camera: camera,
                    groundPlaneStyle: cameraPreset.groundPlaneStyle
                )
                .onChange(of: sample.time) { _, time in
                    guard !isScrubbing, system.duration > .zero else {
                        return
                    }

                    fraction = time / system.duration
                }
                .gesture(
                    DragGesture()
                        .updating($orbitTranslation) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { value in
                            var orbit = perspectiveOrbit
                            orbit.rotate(
                                yawBy: -Float(value.translation.width)
                                    * orbitSensitivity,
                                pitchBy: Float(value.translation.height)
                                    * orbitSensitivity
                            )
                            perspectiveYaw = Double(orbit.yaw)
                            perspectivePitch = Double(orbit.pitch)
                        },
                    isEnabled: cameraPreset == .perspective
                )
                .simultaneousGesture(
                    MagnifyGesture()
                        .updating($zoomMagnification) { value, state, _ in
                            state = value.magnification
                        }
                        .onEnded { value in
                            zoom(by: Float(value.magnification))
                        }
                )
                .onScrollWheel { delta in
                    zoom(by: exp(Float(delta) * scrollZoomSensitivity))
                }
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer(minLength: 0)

                    Inspector(
                        duration: $duration,
                        particleCount: $particleCount,
                        seed: $seed,
                        spawnPreset: $spawnPreset,
                        spawnDomain: $spawnDomain
                    )
                    .scenePadding([.horizontal, .vertical])
                }

                Spacer(minLength: 0)

                ParticleTimeline(
                    fraction: $fraction,
                    isScrubbing: $isScrubbing
                )
                .frame(maxWidth: 500)
                .onChange(of: fraction) { _, fraction in
                    guard isScrubbing else { return }

                    system.seek(to: system.duration * fraction)
                }
            }
        }
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
            duration: .seconds(duration)
        )
        fraction = 0
    }

    private func zoom(by magnification: Float) {
        cameraZoom = Double(
            min(
                max(
                    Float(cameraZoom) * magnification,
                    zoomRange.lowerBound
                ),
                zoomRange.upperBound
            )
        )
    }
}

#Preview {
    ContentView()
}
