import Foundation
import simd

struct EditorSettings: Equatable, RawRepresentable {
    struct Camera: Codable, Equatable {
        var preset = CameraPreset.perspective
        var rotationX = Double(CameraPreset.perspectiveOrbit.rotation.vector.x)
        var rotationY = Double(CameraPreset.perspectiveOrbit.rotation.vector.y)
        var rotationZ = Double(CameraPreset.perspectiveOrbit.rotation.vector.z)
        var rotationW = Double(CameraPreset.perspectiveOrbit.rotation.vector.w)
        var targetX = 0.0
        var targetY = 0.0
        var targetZ = 0.0
        var zoom = 1.0
    }

    struct Visibility: Codable, Equatable {
        var isGroundPlaneVisible = true
        var isInspectorVisible = true
        var isCullingVisible = false
        var isFrustumVisible = false
        var isDataVisible = false
    }

    struct Inspector: Codable, Equatable {
        var horizontalPosition = 1.0
        var verticalPosition = 0.0
    }

    var camera = Camera()
    var observerCamera: Camera?
    var visibility = Visibility()
    var inspector = Inspector()
    var playMode = PlayMode.play

    private struct Representation: Codable {
        var camera: Camera
        var observerCamera: Camera?
        var visibility: Visibility
        var inspector: Inspector
        var playMode: PlayMode

        init(_ settings: EditorSettings) {
            camera = settings.camera
            observerCamera = settings.observerCamera
            visibility = settings.visibility
            inspector = settings.inspector
            playMode = settings.playMode
        }
    }

    init() {}

    init?(rawValue: String) {
        guard
            let defaults = try? JSONEncoder().encode(Representation(Self())),
            let defaultObject = try? JSONSerialization.jsonObject(with: defaults),
            let data = rawValue.data(using: .utf8),
            let storedObject = try? JSONSerialization.jsonObject(with: data)
        else { return nil }
        let merged = Self.merging(storedObject, over: defaultObject)
        guard
            let mergedData = try? JSONSerialization.data(withJSONObject: merged),
            let representation = try? JSONDecoder().decode(
                Representation.self,
                from: mergedData
            )
        else { return nil }
        camera = representation.camera
        observerCamera = representation.observerCamera
        visibility = representation.visibility
        inspector = representation.inspector
        playMode = representation.playMode
    }

    var rawValue: String {
        guard
            let data = try? JSONEncoder().encode(Representation(self)),
            let value = String(data: data, encoding: .utf8)
        else { return "{}" }
        return value
    }

    private static func merging(_ stored: Any, over defaults: Any) -> Any {
        guard
            let stored = stored as? [String: Any],
            var merged = defaults as? [String: Any]
        else { return stored }

        for (key, value) in stored {
            if let defaultValue = merged[key] {
                merged[key] = merging(value, over: defaultValue)
            } else {
                merged[key] = value
            }
        }
        return merged
    }
}
