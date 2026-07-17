import Swift

public struct Sound: Hashable, Sendable {
    package let id: ResourceID

    package init(id: ResourceID) {
        self.id = id
    }
}

public struct Playback: Hashable, Sendable {
    package let id: ResourceID

    package init(id: ResourceID) {
        self.id = id
    }
}

public struct Bus: Hashable, Sendable {
    package let id: ResourceID

    package init(id: ResourceID) {
        self.id = id
    }
}
