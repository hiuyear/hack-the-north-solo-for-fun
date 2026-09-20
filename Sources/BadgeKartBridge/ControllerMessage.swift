import Foundation

enum ControllerMessage: Equatable {
    case ready(sequence: Int)
    case input(sequence: Int, button: String, pressed: Bool, heldMask: Int)
    case boost(sequence: Int, uptimeMS: Int)
    case heartbeat(sequence: Int, heldMask: Int, uptimeMS: Int)

    static func parse(_ rawLine: String) -> ControllerMessage? {
        guard let marker = rawLine.range(of: "KART1|") else { return nil }
        let payload = rawLine[marker.lowerBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fields = payload.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard fields.first == "KART1", fields.count >= 3 else { return nil }

        switch fields[1] {
        case "READY" where fields.count == 3:
            guard let sequence = boundedUInt16(fields[2]) else { return nil }
            return .ready(sequence: sequence)

        case "INPUT" where fields.count == 6:
            guard
                let sequence = boundedUInt16(fields[2]),
                Self.validButtons.contains(fields[3]),
                fields[4] == "0" || fields[4] == "1",
                let heldMask = boundedByte(fields[5])
            else { return nil }
            return .input(
                sequence: sequence,
                button: fields[3],
                pressed: fields[4] == "1",
                heldMask: heldMask
            )

        case "BOOST" where fields.count == 4:
            guard let sequence = boundedUInt16(fields[2]), let uptime = nonnegativeInt(fields[3]) else { return nil }
            return .boost(sequence: sequence, uptimeMS: uptime)

        case "HEARTBEAT" where fields.count == 5:
            guard
                let sequence = boundedUInt16(fields[2]),
                let heldMask = boundedByte(fields[3]),
                let uptime = nonnegativeInt(fields[4])
            else { return nil }
            return .heartbeat(sequence: sequence, heldMask: heldMask, uptimeMS: uptime)

        default:
            return nil
        }
    }

    private static let validButtons: Set<String> = [
        "A", "B", "LEFT", "RIGHT", "UP", "DOWN", "AUX1", "START"
    ]

    private static func boundedUInt16(_ value: String) -> Int? {
        guard let parsed = Int(value), (0...65_535).contains(parsed) else { return nil }
        return parsed
    }

    private static func boundedByte(_ value: String) -> Int? {
        guard let parsed = Int(value), (0...255).contains(parsed) else { return nil }
        return parsed
    }

    private static func nonnegativeInt(_ value: String) -> Int? {
        guard let parsed = Int(value), parsed >= 0 else { return nil }
        return parsed
    }
}

