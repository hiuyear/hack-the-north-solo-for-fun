import Foundation

#if os(macOS)
import Darwin
#endif

enum SerialDiscovery {
    static func usbModemPorts() -> [String] {
        let directory = "/dev"
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            return []
        }
        return names
            .filter { $0.hasPrefix("cu.usbmodem") }
            .sorted()
            .map { "\(directory)/\($0)" }
    }
}

final class SerialReader {
    let path: String
    private let onLine: (String) -> Void
    private let onDisconnect: () -> Void
    private var handle: FileHandle?
    private var buffer = Data()
    private var stopped = false

    init(path: String, onLine: @escaping (String) -> Void, onDisconnect: @escaping () -> Void) {
        self.path = path
        self.onLine = onLine
        self.onDisconnect = onDisconnect
    }

    func start() throws {
        #if os(macOS)
        let fd = path.withCString { Darwin.open($0, O_RDWR | O_NOCTTY | O_NONBLOCK) }
        if fd < 0 {
            let posix = POSIXErrorCode(rawValue: errno) ?? .EIO
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(posix.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Could not open \(path): \(String(cString: strerror(errno)))"]
            )
        }

        var configuration = termios()
        if tcgetattr(fd, &configuration) == 0 {
            cfmakeraw(&configuration)
            cfsetspeed(&configuration, speed_t(B115200))
            configuration.c_cflag |= tcflag_t(CLOCAL | CREAD)
            configuration.c_cflag &= ~tcflag_t(PARENB | CSTOPB | CSIZE)
            configuration.c_cflag |= tcflag_t(CS8)
            withUnsafeMutablePointer(to: &configuration.c_cc) { tuple in
                tuple.withMemoryRebound(to: cc_t.self, capacity: Int(NCCS)) { cc in
                    cc[Int(VMIN)] = 1
                    cc[Int(VTIME)] = 0
                }
            }
            _ = tcsetattr(fd, TCSANOW, &configuration)
        }
        _ = fcntl(fd, F_SETFL, 0)

        handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        handle?.readabilityHandler = { [weak self] file in
            self?.consume(file)
        }
        BridgeLog.line("opened serial \(path)")
        #else
        throw NSError(
            domain: "BadgeKartBridge",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "USB serial is only available on macOS"]
        )
        #endif
    }

    func stop() {
        stopped = true
        handle?.readabilityHandler = nil
        handle = nil
    }

    private func consume(_ file: FileHandle) {
        let chunk = file.availableData
        if chunk.isEmpty {
            if !stopped {
                stopped = true
                BridgeLog.line("serial EOF on \(path)")
                onDisconnect()
            }
            return
        }
        buffer.append(chunk)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            if let line = String(data: Data(lineData), encoding: .utf8) {
                onLine(line)
            }
        }
    }
}
