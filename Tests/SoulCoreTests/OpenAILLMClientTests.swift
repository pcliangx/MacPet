import XCTest
@testable import SoulCore

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var lastBody: Data?
    nonisolated(unsafe) static var sseChunks: [String] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastBody = request.httpBodyStream.map { stream in
            stream.open(); defer { stream.close() }
            var data = Data(); var buf = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let n = stream.read(&buf, maxLength: buf.count)
                if n <= 0 { break }; data.append(buf, count: n)
            }
            return data
        } ?? request.httpBody
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                   httpVersion: nil, headerFields: ["Content-Type": "text/event-stream"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        for chunk in Self.sseChunks { client?.urlProtocol(self, didLoad: Data(chunk.utf8)) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class OpenAILLMClientTests: XCTestCase {
    func makeClient() -> OpenAILLMClient {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubURLProtocol.self]
        return OpenAILLMClient(
            config: LLMConfig(baseURL: URL(string: "https://stub.local/v1")!, apiKey: "k", model: "m"),
            session: URLSession(configuration: cfg))
    }
    func testAssemblesContentDeltas() async throws {
        StubURLProtocol.sseChunks = [
            "data: {\"choices\":[{\"delta\":{\"content\":\"你\"}}]}\n\n",
            "data: {\"choices\":[{\"delta\":{\"content\":\"好\"}}]}\n\n",
            "data: [DONE]\n\n",
        ]
        var got = ""
        let r = try await makeClient().complete(messages: [.user("hi")], tools: [], onDelta: { got += $0 })
        XCTAssertEqual(got, "你好")
        XCTAssertEqual(r.content, "你好")
        XCTAssertNil(r.toolCalls)
    }
    func testAssemblesToolCallArgumentDeltas() async throws {
        StubURLProtocol.sseChunks = [
            #"data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"c1","function":{"name":"speak","arguments":"{\"te"}}]}}]}"# + "\n\n",
            #"data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"xt\":\"hi\"}"}}]}}]}"# + "\n\n",
            "data: [DONE]\n\n",
        ]
        let r = try await makeClient().complete(messages: [.user("hi")],
            tools: [ToolSpec(name: "speak", description: "说话", parametersJSON: #"{"type":"object"}"#)],
            onDelta: { _ in })
        XCTAssertEqual(r.toolCalls?.count, 1)
        XCTAssertEqual(r.toolCalls?.first?.name, "speak")
        XCTAssertEqual(r.toolCalls?.first?.arguments, #"{"text":"hi"}"#)
        let body = String(data: StubURLProtocol.lastBody ?? Data(), encoding: .utf8)!
        XCTAssertTrue(body.contains(#""stream":true"#))
        XCTAssertTrue(body.contains(#""tools""#))
    }
}
