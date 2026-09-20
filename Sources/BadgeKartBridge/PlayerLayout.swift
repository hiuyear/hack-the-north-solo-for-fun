import Foundation

struct MacKey: Equatable {
    let code: UInt16
    let label: String
}

struct PlayerLayout: Equatable {
    let playerNumber: Int
    let name: String
    let accel: MacKey
    let brake: MacKey
    let left: MacKey
    let right: MacKey
    let item: MacKey
    let nitro: MacKey
    let drift: MacKey
    let rescue: MacKey
    let menu: MacKey

    static let player1 = PlayerLayout(
        playerNumber: 1,
        name: "Player 1",
        accel: MacKey(code: 0x7E, label: "UpArrow"),
        brake: MacKey(code: 0x7D, label: "DownArrow"),
        left: MacKey(code: 0x7B, label: "LeftArrow"),
        right: MacKey(code: 0x7C, label: "RightArrow"),
        item: MacKey(code: 0x31, label: "Space"),
        nitro: MacKey(code: 0x2D, label: "N"),
        drift: MacKey(code: 0x09, label: "V"),
        rescue: MacKey(code: 0x75, label: "Delete"),
        menu: MacKey(code: 0x24, label: "Return")
    )

    static let player2 = PlayerLayout(
        playerNumber: 2,
        name: "Player 2",
        accel: MacKey(code: 0x0D, label: "W"),
        brake: MacKey(code: 0x01, label: "S"),
        left: MacKey(code: 0x00, label: "A"),
        right: MacKey(code: 0x02, label: "D"),
        item: MacKey(code: 0x03, label: "F"),
        nitro: MacKey(code: 0x0E, label: "E"),
        drift: MacKey(code: 0x05, label: "G"),
        rescue: MacKey(code: 0x0F, label: "R"),
        menu: MacKey(code: 0x10, label: "Y")
    )

    static func layout(forPlayerNumber number: Int) -> PlayerLayout {
        number == 2 ? player2 : player1
    }

    func key(forButton button: String) -> MacKey? {
        switch button {
        case "A": return accel
        case "B": return brake
        case "LEFT": return left
        case "RIGHT": return right
        case "UP": return item
        case "DOWN": return drift
        case "AUX1": return rescue
        case "START": return menu
        default: return nil
        }
    }

    func actionName(forButton button: String) -> String {
        switch button {
        case "A": return "ACCEL"
        case "B": return "BRAKE"
        case "LEFT": return "STEER_LEFT"
        case "RIGHT": return "STEER_RIGHT"
        case "UP": return "ITEM"
        case "DOWN": return "DRIFT"
        case "AUX1": return "RESCUE"
        case "START": return "MENU"
        default: return button
        }
    }

    var allKeys: [MacKey] {
        [accel, brake, left, right, item, nitro, drift, rescue, menu]
    }
}

protocol KeySink: AnyObject {
    func setKey(_ key: MacKey, down: Bool, player: Int, reason: String)
}

protocol PulseScheduler {
    func after(_ seconds: TimeInterval, perform work: @escaping () -> Void)
}

final class ImmediatePulseScheduler: PulseScheduler {
    func after(_ seconds: TimeInterval, perform work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}

final class PlayerSession {
    static let nitroPulseSeconds: TimeInterval = 0.12
    static let nitroCooldownSeconds: TimeInterval = 0.80

    let layout: PlayerLayout
    private let sink: KeySink
    private let scheduler: PulseScheduler
    private var heldButtons = Set<String>()
    private var nitroHeld = false
    private var nextNitroAllowed = Date.distantPast
    private var nitroPulseID = 0

    init(layout: PlayerLayout, sink: KeySink, scheduler: PulseScheduler = ImmediatePulseScheduler()) {
        self.layout = layout
        self.sink = sink
        self.scheduler = scheduler
    }

    func handle(_ message: ControllerMessage) {
        switch message {
        case .ready:
            BridgeLog.line("\(layout.name) READY")
        case let .input(_, button, pressed, heldMask):
            setButton(button, pressed: pressed, reason: pressed ? "press" : "release")
            applyHeldMask(heldMask, reason: "input-mask")
        case .boost:
            pulseNitro()
        case let .heartbeat(_, heldMask, _):
            applyHeldMask(heldMask, reason: "heartbeat")
        }
    }

    func setButton(_ button: String, pressed: Bool, reason: String) {
        guard let key = layout.key(forButton: button) else { return }
        let alreadyHeld = heldButtons.contains(button)
        if pressed == alreadyHeld { return }
        if pressed {
            heldButtons.insert(button)
        } else {
            heldButtons.remove(button)
        }
        let action = layout.actionName(forButton: button)
        sink.setKey(key, down: pressed, player: layout.playerNumber, reason: "\(action) \(reason)")
    }

    func applyHeldMask(_ mask: Int, reason: String) {
        for pair in ControllerMessage.buttonBits {
            setButton(pair.name, pressed: (mask & pair.bit) != 0, reason: reason)
        }
    }

    func pulseNitro() {
        let now = Date()
        guard now >= nextNitroAllowed else {
            BridgeLog.line("P\(layout.playerNumber) SHAKE ignored (nitro cooldown)")
            return
        }
        nextNitroAllowed = now.addingTimeInterval(Self.nitroCooldownSeconds)
        nitroPulseID += 1
        let pulseID = nitroPulseID
        BridgeLog.line("P\(layout.playerNumber) SHAKE  nitro pulse key=\(layout.nitro.label)")
        setNitro(down: true, reason: "nitro")
        scheduler.after(Self.nitroPulseSeconds) { [weak self] in
            guard let self, self.nitroPulseID == pulseID else { return }
            self.setNitro(down: false, reason: "nitro-end")
        }
    }

    func releaseAll(reason: String) {
        nitroPulseID += 1
        let leftover = heldButtons.sorted()
        if leftover.isEmpty && !nitroHeld {
            BridgeLog.line("P\(layout.playerNumber) all keys UP  (\(reason))")
            return
        }
        BridgeLog.line("P\(layout.playerNumber) releasing \(leftover.joined(separator: ","))\(nitroHeld ? ",NITRO" : "")  (\(reason))")
        for button in leftover {
            setButton(button, pressed: false, reason: reason)
        }
        setNitro(down: false, reason: reason)
        BridgeLog.line("P\(layout.playerNumber) all keys UP  (\(reason))")
    }

    private func setNitro(down: Bool, reason: String) {
        if nitroHeld == down { return }
        nitroHeld = down
        sink.setKey(layout.nitro, down: down, player: layout.playerNumber, reason: reason)
    }
}
