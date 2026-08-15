import SwiftUI
import PixlParticles

struct ContentView: View {
    private let orbitSensitivity: Float = 0.005

    private let system: System = .init(
        particleCount: 201,
        duration: .seconds(20)
    )

    @State private var isPaused: Bool = true
    @State private var fraction: Double = 0
    @State private var isScrubbing: Bool = false
    @State private var cameraPreset = CameraPreset.perspective
    @State private var perspectiveOrbit = CameraPreset.perspectiveOrbit
    @GestureState private var orbitTranslation: CGSize = .zero

    private var camera: Camera {
        guard cameraPreset == .perspective else {
            return cameraPreset.fixedCamera
        }

        return perspectiveOrbit.camera(
            yawOffset: -Float(orbitTranslation.width) * orbitSensitivity,
            pitchOffset: Float(orbitTranslation.height) * orbitSensitivity
        )
    }

    var body: some View {
        ZStack {
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
                            perspectiveOrbit.rotate(
                                yawBy: -Float(value.translation.width)
                                    * orbitSensitivity,
                                pitchBy: Float(value.translation.height)
                                    * orbitSensitivity
                            )
                        },
                    isEnabled: cameraPreset == .perspective
                )
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer(minLength: 0)

                    Inspector()
                        .scenePadding([.horizontal, .top])
                }

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
                .keyboardShortcut(.space, modifiers: [])
            }
        }
    }
}

#Preview {
    ContentView()
}
