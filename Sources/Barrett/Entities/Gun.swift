import Pixl

struct Gun {
    var roundsPerSecond: Double
    private var cooldown: Double = 0

    init(roundsPerSecond: Double) {
        self.roundsPerSecond = roundsPerSecond
    }

    mutating func update(delta: Double) {
        cooldown = max(cooldown - delta, 0)
    }

    mutating func fire() -> Bool {
        guard cooldown <= 0 else {
            return false
        }

        cooldown = 1 / roundsPerSecond
        return true
    }
}

