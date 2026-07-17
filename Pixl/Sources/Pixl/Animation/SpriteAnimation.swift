//import Swift
//
//public struct SpriteAnimation: Equatable, Sendable {
//    public let textureID: TextureID
//    public let frames: [Rect]
//    public let frameDuration: Double
//    public let loops: Bool
//    public let duration: Double
//
//    public init(
//        textureID: TextureID,
//        frames: [Rect],
//        frameDuration: Double,
//        loops: Bool = true
//    ) {
//        self.textureID = textureID
//        self.frames = frames
//        self.frameDuration = frameDuration
//        self.loops = loops
//        self.duration = Double(frames.count) * max(frameDuration, 0)
//    }
//
//    public func frame(at elapsedTime: Double) -> Rect? {
//        guard !frames.isEmpty else { return nil }
//        guard frameDuration > 0 else { return frames.first }
//
//        let frameIndex = Int(max(elapsedTime, 0) / frameDuration)
//
//        if loops {
//            return frames[frameIndex % frames.count]
//        }
//
//        return frames[min(frameIndex, frames.count - 1)]
//    }
//}
//
//extension SpriteAnimation {
//    public struct Timeline: Equatable, Sendable {
//        public let animation: SpriteAnimation
//        public var speed: Double
//        public private(set) var elapsedTime: Double
//
//        public init(animation: SpriteAnimation, timeScale: Double = 1, elapsedTime: Double = 0) {
//            self.animation = animation
//            self.speed = timeScale
//            self.elapsedTime = elapsedTime
//        }
//
//        public mutating func update(delta: Double) {
//            elapsedTime += max(delta, 0) * max(speed, 0)
//        }
//
//        public mutating func reset() {
//            elapsedTime = 0
//        }
//
//        public var frame: Rect? {
//            animation.frame(at: elapsedTime)
//        }
//    }
//}
