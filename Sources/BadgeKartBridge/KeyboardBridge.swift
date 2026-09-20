import ApplicationServices
import Foundation

struct PlayerKeyMap {
    let byButton: [String: CGKeyCode]
    let bitByButton: [String: Int]
    let boost: CGKeyCode

    static let playerOne = PlayerKeyMap(
        byButton: [
            "A": 126,       // Up arrow: accelerate
            "B": 125,       // Down arrow: brake
            "LEFT": 123,
            "RIGHT": 124,
            "UP": 49,       // Space: fire item
            "DOWN": 9,      // V: drift
            "AUX1": 51,     // Delete: rescue
            "START": 36     // Return: menu select
        ],
        bitByButton: ["A": 1, "LEFT": 2, "RIGHT": 4, "B": 8, "UP": 16, "DOWN": 32, "AUX1": 64, "START": 128],
        boost: 45             // N: nitro
    )

    static let playerTwo = PlayerKeyMap(
        byButton: [
            "A": 13,        // W: accelerate
            "B": 1,         // S: brake
            "LEFT": 0,      // A: steer left
            "RIGHT": 2,     // D: steer right
            "UP": 3,        // F: fire item
            "DOWN": 5,      // G: drift
            "AUX1": 15,     // R: rescue
            "START": 16     // Y: menu select
        ],
        bitByButton: ["A": 1, "LEFT": 2, "RIGHT": 4, "B": 8, "UP": 16, "DOWN": 32, "AUX1": 64, "START": 128],
        boost: 14             // E: nitro
    )
}

final class KeyboardEmitter {
    private let source = CGEventSource(stateID: .hidSystemState)
    private var pressedKeys = Set<CGKeyCode>()
    private let lock = NSLock()
    private let dryRun: Bool

    init(dryRun: Bool) {
        self.dryRun = dryRun
    }

    func set(_ key: CGKeyCode, pressed: Bool, player: Int, label: String) {
        lock.lock()
        defer { lock.unlock() }

        if pressed {
            guard pressedKeys.insert(key).inserted else { return }
        } else {
            guard pressedKeys.remove(key) != nil else { return }
        }

        let state = pressed ? "DOWN" : "UP"
        BridgeLog.line("P\(player) \(label) \(state) key=\(key)")
        if dryRun { return }
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: pressed) else { return }
        event.post(tap: .cghidEventTap)
    }

    func pulse(_ key: CGKeyCode, player: Int, label: String) {
        set(key, pressed: true, player: player, label: label)
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(70)) { [weak self] in
            self?.set(key, pressed: false, player: player, label: label)
        }
    }

    func releaseAll() {
        lock.lock()
        let keys = pressedKeys
        pressedKeys.removeAll()
        lock.unlock()

        guard !dryRun else { return }
        for key in keys {
            CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)?.post(tap: .cghidEventTap)
        }
    }
}

final class PlayerController {
    private let player: Int
    private let map: PlayerKeyMap
    private let emitter: KeyboardEmitter
    private var lastSequence: Int?

    init(player: Int, map: PlayerKeyMap, emitter: KeyboardEmitter) {
        self.player = player
        self.map = map
        self.emitter = emitter
    }

    func handle(_ message: ControllerMessage) {
        let sequence: Int
        switch message {
        case .ready(let value), .input(let value, _, _, _), .boost(let value, _), .heartbeat(let value, _, _):
            sequence = value
        }

        if let lastSequence, !Self.isNewer(sequence, than: lastSequence) { return }
        self.lastSequence = sequence

        switch message {
        case .ready:
            BridgeLog.line("Player \(player) controller ready")
        case .input(_, let button, let pressed, _):
            guard let key = map.byButton[button] else { return }
            emitter.set(key, pressed: pressed, player: player, label: button)
        case .boost:
            emitter.pulse(map.boost, player: player, label: "BOOST")
        case .heartbeat(_, let heldMask, _):
            for (button, bit) in map.bitByButton {
                guard let key = map.byButton[button] else { continue }
                emitter.set(key, pressed: heldMask & bit != 0, player: player, label: button)
            }
        }
    }

    func disconnect() {
        emitter.releaseAll()
        BridgeLog.line("Player \(player) controller disconnected; released all keys")
    }

    private static func isNewer(_ candidate: Int, than previous: Int) -> Bool {
        let difference = (candidate - previous + 65_536) % 65_536
        return difference > 0 && difference < 32_768
    }
}
