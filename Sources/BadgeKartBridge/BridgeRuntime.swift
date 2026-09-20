import Foundation

#if os(macOS)
import AppKit
#endif

struct BridgeOptions {
    var demo = false
    var logOnly = false
    var ports: [String] = []
}

enum ArgumentParser {
    static func parse(_ arguments: [String]) -> BridgeOptions {
        var options = BridgeOptions()
        for argument in arguments.dropFirst() {
            switch argument {
            case "--demo":
                options.demo = true
            case "--log-only":
                options.logOnly = true
            case "--help", "-h":
                print(helpText)
                exit(0)
            default:
                if argument.hasPrefix("-") {
                    fputs("unknown option: \(argument)\n\(helpText)\n", stderr)
                    exit(2)
                }
                options.ports.append(argument)
            }
        }
        return options
    }

    static let helpText = """
    Usage: BadgeKartBridge [--demo] [--log-only] [port1 [port2]]

      --demo       Play a canned P1/P2 key sequence without USB
      --log-only   Record button events but never inject keys
      port         Explicit /dev/cu.usbmodem* paths; omit to auto-discover
    """
}

final class BridgeRuntime: NSObject {
    private let options: BridgeOptions
    private let keyboard = KeyboardBridge.shared
    private var sessions: [Int: PlayerSession] = [:]
    private var readers: [SerialReader] = []
    private var assignedPorts: [String: Int] = [:]
    private var watchTimer: Timer?
    private var lastWaitLog = Date.distantPast
    private var busyLogged = Set<String>()

    init(options: BridgeOptions) {
        self.options = options
        super.init()
    }

    func start() {
        BridgeLog.startSession()
        keyboard.injectKeys = !options.logOnly
        printIdentity()
        let trusted = keyboard.refreshAccessibility(prompt: true)
        printAccessibilityStatus(trusted: trusted)

        if options.demo {
            runDemo()
            return
        }

        #if os(macOS)
        attachAvailablePorts()
        watchTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.attachAvailablePorts()
        }
        if let timer = watchTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        #else
        BridgeLog.line("USB serial is not visible on this computer. Use a Mac with the badge on a USB data cable.")
        #endif
    }

    func stop() {
        watchTimer?.invalidate()
        watchTimer = nil
        for session in sessions.values {
            session.releaseAll(reason: "shutdown")
        }
        readers.forEach { $0.stop() }
        readers.removeAll()
        keyboard.releaseEverything(reason: "shutdown")
    }

    private func printIdentity() {
        let bundle = Bundle.main
        BridgeLog.line("bundle id: \(bundle.bundleIdentifier ?? "(none — not launched as BadgeKartBridge.app)")")
        BridgeLog.line("bundle path: \(bundle.bundlePath)")
        BridgeLog.line("executable: \(CommandLine.arguments[0])")
        if bundle.bundleIdentifier != "com.hiuyear.BadgeKartBridge" {
            BridgeLog.line("WARNING: this process is not the installed .app. System Settings will not list it as BadgeKartBridge.")
            BridgeLog.line("Run start.command so ~/Applications/BadgeKartBridge.app is the Accessibility identity.")
        }
    }

    private func printAccessibilityStatus(trusted: Bool) {
        if trusted {
            BridgeLog.line("Accessibility is ON for this process")
            return
        }
        BridgeLog.line("Accessibility is OFF. macOS often does NOT auto-add BadgeKartBridge to the list.")
        BridgeLog.line("Do this, then run start.command again:")
        BridgeLog.line("  1. System Settings → Privacy & Security → Accessibility")
        BridgeLog.line("  2. Click the + button (unlock first if needed)")
        BridgeLog.line("  3. Press Command-Shift-G and paste:  ~/Applications/BadgeKartBridge.app")
        BridgeLog.line("  4. Select BadgeKartBridge.app and turn the switch on")
        BridgeLog.line("Do not enable Terminal, Cursor, or iTerm in place of BadgeKartBridge.app.")
        BridgeLog.line("Serial logging still works; synthesized keys stay blocked until that .app is enabled.")
    }

    private func attachAvailablePorts() {
        let discovered = options.ports.isEmpty ? SerialDiscovery.usbModemPorts() : options.ports
        if discovered.isEmpty && assignedPorts.isEmpty {
            let now = Date()
            if now.timeIntervalSince(lastWaitLog) >= 5 {
                lastWaitLog = now
                BridgeLog.line("waiting for /dev/cu.usbmodem*  (close Badge IDE; use a USB data cable; open Kart Controller)")
            }
            return
        }

        for path in discovered where assignedPorts[path] == nil {
            let used = Set(assignedPorts.values)
            guard let playerNumber = (1...2).first(where: { !used.contains($0) }) else {
                BridgeLog.line("ignoring extra badge \(path) (P1/P2 already assigned)")
                continue
            }
            attach(path: path, playerNumber: playerNumber)
        }

        let missing = assignedPorts.filter { !discovered.contains($0.key) }
        for (path, playerNumber) in missing {
            detach(path: path, playerNumber: playerNumber, reason: "disconnect")
        }
    }

    private func attach(path: String, playerNumber: Int) {
        let layout = PlayerLayout.layout(forPlayerNumber: playerNumber)
        let session = PlayerSession(layout: layout, sink: keyboard)
        let reader = SerialReader(path: path, onLine: { [weak self] line in
            self?.handle(line: line, playerNumber: playerNumber)
        }, onDisconnect: { [weak self] in
            DispatchQueue.main.async {
                self?.detach(path: path, playerNumber: playerNumber, reason: "disconnect")
            }
        })
        do {
            try reader.start()
        } catch {
            if busyLogged.insert(path).inserted {
                BridgeLog.line("failed to open \(path): \(error.localizedDescription)")
                BridgeLog.line("If that port is busy, close the Badge IDE so it releases serial.")
            }
            return
        }
        busyLogged.remove(path)
        sessions[playerNumber] = session
        assignedPorts[path] = playerNumber
        readers.append(reader)
        BridgeLog.line("\(layout.name) controller ready  port=\(path)  keys=\(playerNumber == 1 ? "arrows+Space/N/V/Delete/Return" : "WASD+F/E/G/R/Y")")
    }

    private func detach(path: String, playerNumber: Int, reason: String) {
        let hadSession = sessions[playerNumber] != nil
        let hadPort = assignedPorts[path] != nil
        guard hadSession || hadPort else { return }
        if let session = sessions.removeValue(forKey: playerNumber) {
            session.releaseAll(reason: reason)
        }
        assignedPorts.removeValue(forKey: path)
        if let index = readers.firstIndex(where: { $0.path == path }) {
            readers[index].stop()
            readers.remove(at: index)
        }
        BridgeLog.line("Player \(playerNumber) detached from \(path)")
    }

    private func handle(line: String, playerNumber: Int) {
        guard let message = ControllerMessage.parse(line) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.sessions[playerNumber]?.handle(message)
        }
    }

    func runDemo() {
        BridgeLog.line("demo: both player layouts, including nitro release")
        let p1 = PlayerSession(layout: .player1, sink: keyboard)
        let p2 = PlayerSession(layout: .player2, sink: keyboard)

        func play(_ session: PlayerSession) {
            session.handle(.ready(sequence: 1))
            session.handle(.input(sequence: 2, button: "A", pressed: true, heldMask: 1))
            session.handle(.input(sequence: 3, button: "A", pressed: false, heldMask: 0))
            session.handle(.input(sequence: 4, button: "LEFT", pressed: true, heldMask: 2))
            session.handle(.input(sequence: 5, button: "LEFT", pressed: false, heldMask: 0))
            session.handle(.input(sequence: 6, button: "RIGHT", pressed: true, heldMask: 4))
            session.handle(.input(sequence: 7, button: "RIGHT", pressed: false, heldMask: 0))
            session.handle(.input(sequence: 8, button: "B", pressed: true, heldMask: 8))
            session.handle(.input(sequence: 9, button: "B", pressed: false, heldMask: 0))
            session.handle(.input(sequence: 10, button: "UP", pressed: true, heldMask: 16))
            session.handle(.input(sequence: 11, button: "UP", pressed: false, heldMask: 0))
            session.handle(.input(sequence: 12, button: "DOWN", pressed: true, heldMask: 32))
            session.handle(.input(sequence: 13, button: "DOWN", pressed: false, heldMask: 0))
            session.handle(.input(sequence: 14, button: "AUX1", pressed: true, heldMask: 64))
            session.handle(.input(sequence: 15, button: "AUX1", pressed: false, heldMask: 0))
            session.handle(.input(sequence: 16, button: "START", pressed: true, heldMask: 128))
            session.handle(.input(sequence: 17, button: "START", pressed: false, heldMask: 0))
            session.handle(.boost(sequence: 18, uptimeMS: 2000))
        }

        play(p1)
        play(p2)
        DispatchQueue.main.asyncAfter(deadline: .now() + PlayerSession.nitroPulseSeconds + 0.05) {
            p1.releaseAll(reason: "demo-end")
            p2.releaseAll(reason: "demo-end")
            BridgeLog.line("demo complete")
            #if os(macOS)
            NSApplication.shared.terminate(nil)
            #else
            exit(0)
            #endif
        }
    }
}
