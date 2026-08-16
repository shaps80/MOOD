import Swift

package struct PositionPair {
    package let previous: Position
    package let current: Position

    package init(previous: Position, current: Position) {
        self.previous = previous
        self.current = current
    }
}
