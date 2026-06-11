import XCTest
@testable import SoulCore

final class ProtocolTests: XCTestCase {
    func testRoundTripCoreMessages() throws {
        let msgs: [PeripheralMessage] = [
            .hello(role: "ctl", name: "soulctl", proto: 1),
            .chatUser(text: "你好"),
            .directive(kind: "speak", payload: ["text": .string("嘞！")]),
            .senseEvent(Percept(id: "p1", kind: "cc.waiting", priority: .alert,
                                payload: ["session": .string("s1")],
                                actions: [PerceptAction(id: "return", label: "带我回去")],
                                at: Date(timeIntervalSince1970: 0))),
            .toolCall(id: "t1", name: "speak", args: ["text": .string("hi")]),
            .fuelReport(date: "2026-06-11", raw: 1234),
            .actionInvoke(eventId: "p1", actionId: "return"),
        ]
        for m in msgs {
            let line = try LineCodec.encode(m)
            XCTAssertTrue(line.last == UInt8(ascii: "\n"))
            let decoded = try LineCodec.decodeLine(line.dropLast())
            XCTAssertEqual(decoded, m)
        }
    }
    func testUnknownTypeIsTolerated() throws {
        let raw = Data(#"{"t":"future.thing","x":1}"#.utf8)
        XCTAssertEqual(try LineCodec.decodeLine(raw), .unknown(t: "future.thing"))
    }
    func testFeedSplitsLines() throws {
        var codec = LineCodec()
        let chunk = Data(#"{"t":"ping"}"# .utf8) + Data("\n".utf8) + Data(#"{"t":"po"# .utf8)
        var got = try codec.feed(chunk)
        XCTAssertEqual(got, [.ping])
        got = try codec.feed(Data(#"ng"}"# .utf8) + Data("\n".utf8))
        XCTAssertEqual(got, [.pong])
    }
}
