import XCTest
@testable import BadgeKartBridge

final class ControllerMessageTests: XCTestCase {
    func testParsesTaggedInputLine() {
        XCTAssertEqual(
            ControllerMessage.parse("[badge_kart] KART1|INPUT|42|A|1|5\r\n"),
            .input(sequence: 42, button: "A", pressed: true, heldMask: 5)
        )
    }

    func testParsesBoostAndHeartbeat() {
        XCTAssertEqual(ControllerMessage.parse("KART1|BOOST|9|1234"), .boost(sequence: 9, uptimeMS: 1234))
        XCTAssertEqual(
            ControllerMessage.parse("KART1|HEARTBEAT|10|128|1500"),
            .heartbeat(sequence: 10, heldMask: 128, uptimeMS: 1500)
        )
    }

    func testRejectsMalformedOrOutOfRangeMessages() {
        XCTAssertNil(ControllerMessage.parse("ordinary firmware log"))
        XCTAssertNil(ControllerMessage.parse("KART1|INPUT|2|UNKNOWN|1|0"))
        XCTAssertNil(ControllerMessage.parse("KART1|INPUT|2|A|2|0"))
        XCTAssertNil(ControllerMessage.parse("KART1|HEARTBEAT|2|999|10"))
        XCTAssertNil(ControllerMessage.parse("KART1|READY|70000"))
    }
}

