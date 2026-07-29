import Foundation

extension Font {
    final class Registry: @unchecked Sendable {
        static let shared = Registry()

        private static let systemURL = URL(filePath: "/System/Library/Fonts/Supplemental/Zapfino.ttf")

        private let lock = NSLock()
        private let sfnt = SFNT.Registry()
        private var systemFace: SFNT.Face?

        private init() {}

        func face(for descriptor: Descriptor) throws -> SFNT.Face {
            switch descriptor.source {
            case .system:
                return try loadSystemFace()
            }
        }

        private func loadSystemFace() throws -> SFNT.Face {
            lock.lock()
            defer { lock.unlock() }

            if let systemFace {
                return systemFace
            }

            let bytes = try Array(Data(contentsOf: Self.systemURL))
            let face = try sfnt.register(bytes: bytes)
            systemFace = face
            return face
        }
    }
}
