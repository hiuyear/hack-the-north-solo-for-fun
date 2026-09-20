import XCTest
@testable import BadgeKartBridge

final class PlayerLayoutTests: XCTestCase {
    func testPlayerLayoutsDoNotShareKeys() {
        let p1 = Set(PlayerLayout.player1.allKeys.map(\.code))
        let p2 = Set(PlayerLayout.player2.allKeys.map(\.code))
        XCTAssertTrue(p1.isDisjoint(with: p2))
        XCTAssertEqual(PlayerLayout.player1.accel.label, "UpArrow")
        XCTAssertEqual(PlayerLayout.player1.nitro.label, "N")
        XCTAssertEqual(PlayerLayout.player2.accel.label, "W")
        XCTAssertEqual(PlayerLayout.player2.nitro.label, "E")
    }

    func testHeartbeatAndDisconnectReleaseHeldAccelerate() {
        let sink = RecordingSink()
        let session = PlayerSession(layout: .player1, sink: sink)
        session.handle(.input(sequence: 1, button: "A", pressed: true, heldMask: 1))
        XCTAssertEqual(sink.labels, ["UpArrow DOWN"])

        session.handle(.heartbeat(sequence: 2, heldMask: 0, uptimeMS: 10))
        XCTAssertEqual(sink.labels.last, "UpArrow UP")

        session.handle(.input(sequence: 3, button: "A", pressed: true, heldMask: 1))
        session.releaseAll(reason: "disconnect")
        XCTAssertEqual(sink.labels.last, "UpArrow UP")
        XCTAssertFalse(sink.labels.contains("W DOWN"))
    }

    func testShakePulsesNitroOnceThenSchedulerReleases() {
        let sink = RecordingSink()
        let scheduler = ManualScheduler()
        let session = PlayerSession(layout: .player2, sink: sink, scheduler: scheduler)
        session.handle(.boost(sequence: 1, uptimeMS: 9))
        XCTAssertEqual(sink.labels, ["E DOWN"])
        XCTAssertEqual(scheduler.pending.count, 1)
        scheduler.runPending()
        XCTAssertEqual(sink.labels, ["E DOWN", "E UP"])
    }
}

final class RecordingSink: KeySink {
    var labels: [String] = []

    func setKey(_ key: MacKey, down: Bool, player: Int, reason: String) {
        labels.append("\(key.label) \(down ? "DOWN" : "UP")")
    }
}

final class ManualScheduler: PulseScheduler {
    var pending: [() -> Void] = []

    func after(_ seconds: TimeInterval, perform work: @escaping () -> Void) {
        pending.append(work)
    }

    func runPending() {
        let jobs = pending
        pending.removeAll()
        jobs.forEach { $0() }
    }
}
