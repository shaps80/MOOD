import Swift

/// The currently connected game controllers, ordered by player index.
public final class Gamepads: RandomAccessCollection {
    public typealias Element = Gamepad
    public typealias Index = Int

    private var connected: ContiguousArray<Gamepad> = []
    private var slots: ContiguousArray<Gamepad?> = []

    public init() {}

    public var startIndex: Int { 0 }
    public var endIndex: Int { connected.count }

    public subscript(position: Int) -> Gamepad {
        connected[position]
    }

    public subscript(safe position: Int) -> Gamepad {
        guard indices.contains(position) else {
            return .init(index: -1, name: "No Gamepad")
        }
        return self[position]
    }

    package func gamepad(at index: Int, name: String) -> Gamepad? {
        guard index >= 0 else { return nil }
        if index >= slots.count {
            slots.append(contentsOf: repeatElement(
                nil,
                count: index - slots.count + 1
            ))
        }
        if let gamepad = slots[index] {
            if !gamepad.isConnected {
                gamepad.reconnect(name: name)
                insertConnected(gamepad)
                print("Gamepad connected [\(index)]: \(name)")
            }
            return gamepad
        }

        let gamepad = Gamepad(index: index, name: name)
        slots[index] = gamepad
        insertConnected(gamepad)
        print("Gamepad connected [\(index)]: \(name)")
        return gamepad
    }

    package func disconnect(at index: Int) {
        guard slots.indices.contains(index),
              let gamepad = slots[index],
              gamepad.isConnected
        else {
            return
        }
        gamepad.disconnect()
        gamepad.publishPendingEvents()
        connected.removeAll { $0 === gamepad }
        print("Gamepad disconnected [\(index)]: \(gamepad.name)")
    }

    package var slotCount: Int {
        slots.count
    }

    package func publishPendingEvents() {
        for gamepad in connected {
            gamepad.publishPendingEvents()
        }
    }

    private func insertConnected(_ gamepad: Gamepad) {
        let insertion = connected.firstIndex { $0.index > gamepad.index }
            ?? connected.endIndex
        connected.insert(gamepad, at: insertion)
    }
}
