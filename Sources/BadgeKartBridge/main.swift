import ApplicationServices
import Foundation

private func discoverBadgePorts() -> [String] {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? []
    return names
        .filter { $0.hasPrefix("cu.usbmodem") }
        .sorted()
        .prefix(2)
        .map { "/dev/\($0)" }
}

private func runDemo() {
    let p1Emitter = KeyboardEmitter(dryRun: true)
    let p2Emitter = KeyboardEmitter(dryRun: true)
    let p1 = PlayerController(player: 1, map: .playerOne, emitter: p1Emitter)
    let p2 = PlayerController(player: 2, map: .playerTwo, emitter: p2Emitter)
    [
        "KART1|READY|1",
        "KART1|INPUT|2|A|1|1",
        "KART1|INPUT|3|LEFT|1|3",
        "KART1|INPUT|4|LEFT|0|1",
        "KART1|BOOST|5|1500",
        "KART1|INPUT|6|A|0|0"
    ].compactMap(ControllerMessage.parse).forEach(p1.handle)
    [
        "firmware: KART1|READY|1",
        "firmware: KART1|INPUT|2|A|1|1",
        "firmware: KART1|INPUT|3|RIGHT|1|5",
        "firmware: KART1|BOOST|4|1800",
        "firmware: KART1|HEARTBEAT|5|0|2000"
    ].compactMap(ControllerMessage.parse).forEach(p2.handle)
    Thread.sleep(forTimeInterval: 0.1)
}

BridgeLog.startSession()

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("--demo") {
    runDemo()
    exit(EXIT_SUCCESS)
}

let explicitPorts = arguments.filter { !$0.hasPrefix("--") }
let ports = explicitPorts.isEmpty ? discoverBadgePorts() : Array(explicitPorts.prefix(2))
guard !ports.isEmpty else {
    BridgeLog.line("No badge found. Connect a badge by USB, open Kart Controller on it, and retry.")
    exit(EXIT_FAILURE)
}

let permissionOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(permissionOptions) {
    BridgeLog.line("Accessibility is OFF for this process. Do not enable Cursor/Terminal.")
    BridgeLog.line("System Settings → Privacy & Security → Accessibility → +")
    BridgeLog.line("Command-Shift-G → ~/Applications/BadgeKartBridge.app → enable it, then run start.command again.")
    exit(EXIT_FAILURE)
}

var emitters: [KeyboardEmitter] = []
var readers: [SerialReader] = []
for (index, path) in ports.enumerated() {
    let player = index + 1
    let map: PlayerKeyMap = player == 1 ? .playerOne : .playerTwo
    let emitter = KeyboardEmitter(dryRun: false)
    emitters.append(emitter)
    let controller = PlayerController(player: player, map: map, emitter: emitter)
    let reader = SerialReader(
        path: path,
        player: player,
        onLine: { line in
            BridgeLog.line("P\(player) serial: \(line)")
            guard let message = ControllerMessage.parse(line) else { return }
            controller.handle(message)
        },
        onDisconnect: { controller.disconnect() }
    )
    do {
        try reader.start()
        readers.append(reader)
        BridgeLog.line("Player \(player): \(path)")
    } catch {
        BridgeLog.line("\(error)")
    }
}

guard !readers.isEmpty else { exit(EXIT_FAILURE) }
BridgeLog.line("Badge Kart Bridge is running. Keep start.command open; Control-C stops it.")

signal(SIGINT, SIG_IGN)
let interrupt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
interrupt.setEventHandler {
    readers.forEach { $0.stop() }
    emitters.forEach { $0.releaseAll() }
    exit(EXIT_SUCCESS)
}
interrupt.resume()
dispatchMain()
