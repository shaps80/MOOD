import Pixl

extension SoundID {
    public static let laser: Self = "laser"
    public static let hit: Self = "hit"
    public static let empty: Self = "empty"
    public static let levelup: Self = "levelup"
    public static let gameover: Self = "gameover"
    public static let boom: Self = "boom"
    public static let win: Self = "win"
}

extension SoundAsset {
    public static let hit: Self = .init(
        id: .hit,
        path: "assets/audio/hit.wav"
    )

    public static let laser: Self = .init(
        id: .laser,
        path: "assets/audio/laser.wav"
    )

    public static let empty: Self = .init(
        id: .empty,
        path: "assets/audio/empty.wav"
    )

    public static let levelup: Self = .init(
        id: .levelup,
        path: "assets/audio/levelup.wav"
    )

    public static let gameover: Self = .init(
        id: .gameover,
        path: "assets/audio/gameover.wav"
    )

    public static let boom: Self = .init(
        id: .boom,
        path: "assets/audio/boom.wav"
    )

    public static let win: Self = .init(
        id: .win,
        path: "assets/audio/win.wav"
    )
}
