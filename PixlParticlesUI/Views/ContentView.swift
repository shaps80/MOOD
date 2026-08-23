import PixlEditorSupport
import PixlParticles
import PixlRenderer
import Panels
import SwiftUI

struct ContentView: View {
    enum PanelKind: String, Codable, Sendable {
        case properties
        case metrics
    }

    @Environment(\.undoManager) private var undoManager
    @Bindable var document: ParticleDocument
    @SceneStorage("editor.settings") private var settings = EditorSettings()
    @SceneStorage("editor.panels") private var customization: PanelCustomization<PanelKind> = .init()

    @State private var system: System
    @State private var playback = PlaybackState()
    @State private var metrics = RenderMetrics()
    @State private var topInspector: String?

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
                    capturesDiagnostics: true,
                    metrics: metrics,
                    onPlaybackComplete: completePlayback
                )
                .ignoresSafeArea()
                .overlay(alignment: .bottomLeading) {
                    if customization[visibility: .metrics] == .hidden {
                        MetricsOverlay(metrics: metrics)
                            .frame(maxWidth: 200, alignment: .bottomLeading)
                            .transition(.panel(anchor: .bottom))
                            .scenePadding()
                    }
                }

                PanelView(customization: $customization) {
                    Panel(id: .properties) {
                        PropertiesInspector(
                            document: document,
                            system: $system,
                            playback: $playback
                        )
                    }
                    .defaultPlacement(.trailing)
                    .width(300)

                    Panel(id: .metrics) {
                        MetricsInspector(
                            metrics: metrics
                        )
                    }
                    .defaultVisibility(.hidden)
                    .defaultPlacement(.leading)
                    .width(250)
                }
                .scenePadding()

                ParticleTimeline(
                    playback: playback,
                    playMode: $settings.playMode,
                    togglePlayback: togglePlayback
                )
                .frame(maxWidth: 500)
                .ignoresSafeArea()
            }
            .animation(.smooth.speed(2), value: customization)
            .background(.quinary)
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Picker("Camera", selection: $settings.camera.preset) {
                        Text("Orbital").tag(CameraPreset.perspective)
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
                                "Metrics",
                                isOn: .init(
                                    get: { customization[visibility: .metrics] != .hidden },
                                    set: { customization[visibility: .metrics] = $0 ? .visible : .hidden }
                                )
                            )

                            Toggle(
                                "Properties",
                                isOn: .init(
                                    get: { customization[visibility: .properties] != .hidden },
                                    set: { customization[visibility: .properties] = $0 ? .visible : .hidden }
                                )
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

    private static func emitter(
        from snapshot: ParticleDocument.Snapshot
    ) -> Emitter {
        EmitterPreset.debris.emitter().applying(snapshot)
    }
}
