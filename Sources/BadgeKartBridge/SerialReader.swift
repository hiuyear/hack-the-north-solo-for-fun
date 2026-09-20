import Darwin
import Foundation

enum SerialError: Error, CustomStringConvertible {
    case openFailed(String, Int32)
    case configureFailed(String)

    var description: String {
        switch self {
        case .openFailed(let path, let code): return "Could not open \(path) (errno \(code))"
        case .configureFailed(let path): return "Could not configure \(path) at 115200 baud"
        }
    }
}

final class SerialReader {
    let path: String
    private let onLine: (String) -> Void
    private let onDisconnect: () -> Void
    private var descriptor: Int32 = -1
    private var running = false
    private let queue: DispatchQueue

    init(path: String, player: Int, onLine: @escaping (String) -> Void, onDisconnect: @escaping () -> Void) {
        self.path = path
        self.onLine = onLine
        self.onDisconnect = onDisconnect
        self.queue = DispatchQueue(label: "badge.serial.player\(player)")
    }

    func start() throws {
        descriptor = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard descriptor >= 0 else { throw SerialError.openFailed(path, errno) }

        var settings = termios()
        guard tcgetattr(descriptor, &settings) == 0 else {
            closeDescriptor()
            throw SerialError.configureFailed(path)
        }
        cfmakeraw(&settings)
        cfsetspeed(&settings, speed_t(B115200))
        settings.c_cflag |= tcflag_t(CLOCAL | CREAD)
        settings.c_cflag &= ~tcflag_t(HUPCL)
        guard tcsetattr(descriptor, TCSANOW, &settings) == 0 else {
            closeDescriptor()
            throw SerialError.configureFailed(path)
        }

        // Espressif USB-Serial-JTAG treats DTR/RTS as reset. Never assert them.
        var modemSignals = Int32(TIOCM_DTR | TIOCM_RTS)
        _ = ioctl(descriptor, TIOCMBIC, &modemSignals)
        running = true
        queue.async { [weak self] in self?.readLoop() }
    }

    func stop() {
        running = false
        closeDescriptor()
    }

    private func readLoop() {
        var pending = ""
        var bytes = [UInt8](repeating: 0, count: 512)

        while running {
            let count = bytes.withUnsafeMutableBytes { buffer in
                Darwin.read(descriptor, buffer.baseAddress, buffer.count)
            }
            if count > 0 {
                pending += String(decoding: bytes[0..<count], as: UTF8.self)
                while let newline = pending.firstIndex(of: "\n") {
                    let line = String(pending[..<newline])
                    pending.removeSubrange(...newline)
                    onLine(line)
                }
            } else if count < 0 && errno != EINTR && errno != EAGAIN && errno != EWOULDBLOCK {
                break
            } else {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }

        closeDescriptor()
        onDisconnect()
    }

    private func closeDescriptor() {
        if descriptor >= 0 {
            Darwin.close(descriptor)
            descriptor = -1
        }
    }
}
