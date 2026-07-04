import Pixl

struct InvaderWave: GameSystem {
    private var direction: Double = 1
    private let speed: Double = 80
    private let stepDown: Double = GameConfig.invaderSize.y
    private var rowByInvader: [EntityID: Int] = [:]

    mutating func update(context: inout Game.SystemContext) {
        let invaders = context.ids(kind: Invader.self)

        guard !invaders.isEmpty else {
            context.restart()
            return
        }

        updateRowAssignments(invaders: invaders, context: context)

        let rowIDs = Dictionary(grouping: invaders) { id in
            rowByInvader[id] ?? 0
        }

        let shouldStepDown = rowIDs.contains { row in
            let rowIndex = row.key
            let ids = row.value

            guard let bounds = context.bounds(for: ids) else {
                return false
            }

            let movement = Vec2(
                x: direction * speedForRow(rowIndex) * context.delta,
                y: 0
            )
            let proposed = bounds.translated(by: movement)

            return proposed.minX < GameConfig.playBounds.minX
                || proposed.maxX > GameConfig.playBounds.maxX
        }

        if shouldStepDown {
            direction *= -1
        }

        for rowIndex in rowIDs.keys.sorted() {
            guard let ids = rowIDs[rowIndex] else {
                continue
            }

            let movement = Vec2(
                x: direction * speedForRow(rowIndex) * context.delta,
                y: shouldStepDown ? stepDown : 0
            )

            context.move(ids, by: movement)
        }
    }

    private mutating func updateRowAssignments(
        invaders: [EntityID],
        context: Game.SystemContext
    ) {
        let activeInvaders = Set(invaders)
        rowByInvader = rowByInvader.filter { activeInvaders.contains($0.key) }

        let unknown = invaders.filter { rowByInvader[$0] == nil }
        guard !unknown.isEmpty else { return }

        let sorted = unknown
            .compactMap { id -> (id: EntityID, centerY: Double)? in
                guard let bounds = context.bounds(for: id) else { return nil }
                return (id, bounds.center.y)
            }
            .sorted { $0.centerY < $1.centerY }

        let rowThreshold = GameConfig.invaderSize.y
        var rowIndex = (rowByInvader.values.max() ?? -1) + 1
        var previousY: Double?

        for invader in sorted {
            if let previousY, abs(invader.centerY - previousY) > rowThreshold {
                rowIndex += 1
            }

            rowByInvader[invader.id] = rowIndex
            previousY = invader.centerY
        }
    }

    private func speedForRow(_ row: Int) -> Double {
        let seed = Double(row + 1)
        let value = sin(.radians(seed * 12.9898)) * 43758.5453123
        let unit = value - value.rounded(.down)

        return speed * (0.75 + (unit * 0.5))
    }
}
