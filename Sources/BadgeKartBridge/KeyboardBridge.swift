import Foundation

#if os(macOS)
import ApplicationServices
import CoreGraphics
#endif

final class KeyboardBridge: KeySink {
    static let shared = KeyboardBridge()

    var injectKeys = true
    private(set) var accessibilityTrusted = false
    private let lock = NSLock()
    private var downCounts: [UInt16: Int] = [:]

    @discardableResult
    func refreshAccessibility(prompt: Bool) -> Bool {
        #if os(macOS)
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        } else {
            accessibilityTrusted = AXIsProcessTrusted()
        }
        #else
        accessibilityTrusted = false
        #endif
        return accessibilityTrusted
    }

    func setKey(_ key: MacKey, down: Bool, player: Int, reason: String) {
        lock.lock()
        let previous = downCounts[key.code, default: 0]
        let next = max(0, previous + (down ? 1 : -1))
        downCounts[key.code] = next
        let edge = down ? previous == 0 : next == 0
        lock.unlock()

        let phase = down ? "DOWN" : "UP"
        var suffix = "P\(player) \(key.label) \(phase)  \(reason)"
        if !injectKeys {
            suffix += "  (log-only)"
        } else if !accessibilityTrusted {
            suffix += "  (not injected: Accessibility off)"
        } else if !edge {
            suffix += "  (held by another player)"
        }
        BridgeLog.line(suffix)

        guard injectKeys, accessibilityTrusted, edge else { return }
        post(key.code, down: down)
    }

    func releaseEverything(reason: String) {
        lock.lock()
        let held = downCounts.filter { $0.value > 0 }.map(\.key)
        downCounts.removeAll()
        lock.unlock()
        for code in held {
            BridgeLog.line("global key \(code) UP  (\(reason))")
            if injectKeys, accessibilityTrusted {
                post(code, down: false)
            }
        }
    }

    private func post(_ code: UInt16, down: Bool) {
        #if os(macOS)
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else { return }
        event.flags = []
        event.post(tap: .cghidEventTap)
        #endif
    }
}
