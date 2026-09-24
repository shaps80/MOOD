import PixlRenderer
import Swift

/// Immutable semantic colours and their shared premultiplied linear HDR table.
/// Current authoring compiles one entry; the index format supports 65,536.
final class ParticleColorPalette {
    let storage: HostBuffer
    private let colors: [Color]

    init(_ colors: [Color]) {
        precondition(!colors.isEmpty && colors.count <= 65_536)
        self.colors = colors
        storage = HostBuffer(byteCount: colors.count * MemoryLayout<SIMD4<Float>>.stride)
        let values = storage.bindMemory(to: SIMD4<Float>.self, count: colors.count)
        for (index, color) in colors.enumerated() {
            values.initializeElement(at: index, to: [
                color.red * color.alpha, color.green * color.alpha,
                color.blue * color.alpha, color.alpha
            ])
        }
    }

    @inline(__always)
    func index(of color: Color) -> UInt16 {
        guard let index = colors.firstIndex(of: color) else {
            preconditionFailure("Particle colour is absent from the compiled palette")
        }
        return UInt16(index)
    }

    subscript(_ index: UInt16) -> Color { colors[Int(index)] }
}
