import PixlParticles

struct Orbit {
    var target: Vec3
    var distance: Float
    var yaw: Float
    var pitch: Float
    var projection: Projection

    func camera(
        yawOffset: Float = 0,
        pitchOffset: Float = 0
    ) -> Camera {
        Camera(
            orbiting: target,
            distance: distance,
            yaw: yaw + yawOffset,
            pitch: Self.clamp(pitch + pitchOffset),
            projection: projection
        )
    }

    mutating func rotate(
        yawBy yawOffset: Float,
        pitchBy pitchOffset: Float
    ) {
        yaw += yawOffset
        pitch = Self.clamp(pitch + pitchOffset)
    }

    private static func clamp(_ pitch: Float) -> Float {
        let limit = Float.pi / 2 - Float.pi / 180
        return min(max(pitch, -limit), limit)
    }
}
