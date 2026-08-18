import PixlRenderer
import Swift

final class EmitterArena {
    let layout: EmitterStorageLayout
    let storage: HostBuffer

    init(layout: EmitterStorageLayout) {
        self.layout = layout
        storage = HostBuffer(byteCount: layout.byteCount)
    }
}
