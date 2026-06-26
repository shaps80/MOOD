import Swift

public struct Sound: Equatable, Sendable {
    public let id: SoundID

    public init(id: SoundID) {
        self.id = id
    }
}
