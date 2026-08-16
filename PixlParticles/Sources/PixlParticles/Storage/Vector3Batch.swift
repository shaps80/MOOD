import Swift

package struct Vector3Batch {
    package var x: SIMD4<Float>
    package var y: SIMD4<Float>
    package var z: SIMD4<Float>

    init(repeating value: Vec3) {
        x = .init(repeating: value.x)
        y = .init(repeating: value.y)
        z = .init(repeating: value.z)
    }

    subscript(lane: Int) -> Vec3 {
        get { [x[lane], y[lane], z[lane]] }
        set {
            x[lane] = newValue.x
            y[lane] = newValue.y
            z[lane] = newValue.z
        }
    }
}
