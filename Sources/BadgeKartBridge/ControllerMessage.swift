import Foundation

enum ControllerMessage: Equatable {
    case ready(sequence: Int)
    case input(sequence: Int, button: String, pressed: Bool, heldMask: Int)
    case boost(sequence: Int, uptimeMS: Int)
    case heartbeat(sequence: Int, heldMask: Int, uptimeMS: Int)

    static let protocolPrefix = "KART1|"
    static let validButtons: Set<String> = [
        "A", "B", "LEFT", "RIGHT", "UP", "DOWN", "AUX1", "START"
    ]

    static let buttonBits: [(name: String, bit: Int)] = [
        ("A", 1),
        ("LEFT", 2),
        ("RIGHT", 4),
        ("B", 8),
        ("UP", 16),
        ("DOWN", 32),
        ("AUX1", 64),
        ("START", 128)
    ]

    static func parse(_ raw: String) -> ControllerMessage? {
        var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let marker = line.range(of: Self.protocolPrefix) else { return nil }
        line = String(line[marker.lowerBound...])

        let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3, parts[0] == "KART1" else { return nil }

        switch parts[1] {
        case "READY":
            guard parts.count == 3, let sequence = parseSequence(parts[2]) else { return nil }
            return .ready(sequence: sequence)
        case "INPUT":
            guard parts.count == 6,
                  let sequence = parseSequence(parts[2]),
                  validButtons.contains(parts[3]),
                  let pressed = parseFlag(parts[4]),
                  let heldMask = parseMask(parts[5])
            else { return nil }
            return .input(sequence: sequence, button: parts[3], pressed: pressed, heldMask: heldMask)
        case "BOOST":
            guard parts.count == 4,
                  let sequence = parseSequence(parts[2]),
                  let uptimeMS = parseNonNegativeInt(parts[3])
            else { return nil }
            return .boost(sequence: sequence, uptimeMS: uptimeMS)
        case "HEARTBEAT":
            guard parts.count == 5,
                  let sequence = parseSequence(parts[2]),
                  let heldMask = parseMask(parts[3]),
                  let uptimeMS = parseNonNegativeInt(parts[4])
            else { return nil }
            return .heartbeat(sequence: sequence, heldMask: heldMask, uptimeMS: uptimeMS)
        default:
            return nil
        }
    }

    private static func parseSequence(_ raw: String) -> Int? {
        parseInt(raw, max: 65535)
    }

    private static func parseMask(_ raw: String) -> Int? {
        parseInt(raw, max: 255)
    }

    private static func parseFlag(_ raw: String) -> Bool? {
        switch raw {
        case "0": return false
        case "1": return true
        default: return nil
        }
    }

    private static func parseNonNegativeInt(_ raw: String) -> Int? {
        parseInt(raw, max: Int.max)
    }

    private static func parseInt(_ raw: String, max: Int) -> Int? {
        guard let value = Int(raw), value >= 0, value <= max else { return nil }
        return value
    }
}
