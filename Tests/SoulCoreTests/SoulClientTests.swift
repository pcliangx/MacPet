import XCTest
@testable import SoulCore

final class SoulClientTests: XCTestCase {
    func testMessageHandlerRoutesCorrectly() async {
        let client = SoulClient(socketPath: "/tmp/nonexistent-\(UUID().uuidString).sock")
        var received: [PeripheralMessage] = []
        await client.setMessageHandler { msg in received.append(msg) }
        await client.handleReceived(.helloOK(proto: 1, soulVersion: "0.2.0-m1"))
        await client.handleReceived(.chatDelta(text: "你好"))
        await client.handleReceived(.directive(kind: "speak", payload: ["text": .string("嗨！")]))
        XCTAssertEqual(received.count, 3)
    }
    func testSendBufferingWhenDisconnected() async {
        let client = SoulClient(socketPath: "/tmp/nonexistent.sock")
        await client.send(.ping)
        await client.send(.chatUser(text: "test"))
        let pending = await client.pendingSendCount
        XCTAssertEqual(pending, 2)
    }
    func testHandshakeSendsHello() async {
        let client = SoulClient(socketPath: "/tmp/test.sock")
        let hello = await client.makeHello()
        if case .hello(let role, let name, let proto) = hello {
            XCTAssertEqual(role, "body"); XCTAssertEqual(name, "MpetApp"); XCTAssertEqual(proto, 1)
        } else { XCTFail("expected hello") }
    }
}
