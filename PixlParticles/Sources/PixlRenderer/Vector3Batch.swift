import Swift

package struct Vector3Batch {
    package var x: SIMD4<Float>
    package var y: SIMD4<Float>
    package var z: SIMD4<Float>

    package init(repeating value: SIMD3<Float>) {
        x = .init(repeating: value.x)
        y = .init(repeating: value.y)
        z = .init(repeating: value.z)
    }

    package subscript(lane: Int) -> SIMD3<Float> {
        get { [x[lane], y[lane], z[lane]] }
        set {
            x[lane] = newValue.x
            y[lane] = newValue.y
            z[lane] = newValue.z
        }
    }
}
