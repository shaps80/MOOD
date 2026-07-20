import Swift

/// The currently connected game controllers, ordered by player index.
public final class Gamepads: RandomAccessCollection {
    /// Connected controller element type.
    public typealias Element = Gamepad
    /// Integer collection index.
    public typealias Index = Int

    private var connected: ContiguousArray<Gamepad> = []
    private var slots: ContiguousArray<Gamepad?> = []

    /// Creates an empty connected-controller collection.
    public init() {}

    /// Index of the first connected controller.
    public var startIndex: Int { 0 }
    /// Position one past the final connected controller.
    public var endIndex: Int { connected.count }

    /// Returns the connected controller at a valid collection position.
    /// - Parameter position: Index into the compact connected-controller list, not a player slot.
    /// - Returns: The connected controller at `position`.
    public subscript(position: Int) -> Gamepad {
        connected[position]
    }

    /// Returns a connected controller or a placeholder for an invalid position.
    /// - Parameter position: Index into the compact connected-controller list.
    /// - Returns: The connected controller, or a "No Gamepad" placeholder.
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
