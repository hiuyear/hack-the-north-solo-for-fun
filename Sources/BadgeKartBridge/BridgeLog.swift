import Foundation

enum BridgeLog {
    static let logURL: URL = {
        let logs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent("BadgeKartBridge.log")
    }()

    private static let lock = NSLock()
    private static var fileHandle: FileHandle?
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func startSession() {
        lock.lock()
        defer { lock.unlock() }
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        fileHandle = try? FileHandle(forWritingTo: logURL)
        _ = try? fileHandle?.seekToEnd()
        writeLocked("======== BadgeKartBridge start \(formatter.string(from: Date())) ========")
        writeLocked("log file: \(logURL.path)")
    }

    static func line(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        writeLocked(message)
    }

    private static func writeLocked(_ message: String) {
        let stamped = "[\(formatter.string(from: Date()))] \(message)"
        fputs(stamped + "\n", stdout)
        fflush(stdout)
        if let data = (stamped + "\n").data(using: .utf8) {
            fileHandle?.write(data)
        }
    }
}
