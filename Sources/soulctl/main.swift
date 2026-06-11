// Sources/soulctl/main.swift
import Foundation
import Network
import SoulCore

// 用法：soulctl status | chat <text> | event <kind> | sense <kind> <ambient|nudge|alert> | probe

func SoulConfig_loadForCtl() throws -> LLMConfig {
    if let base = ProcessInfo.processInfo.environment["MPET_BASE_URL"],
       let url = URL(string: base) {
        return LLMConfig(baseURL: url,
                         apiKey: ProcessInfo.processInfo.environment["MPET_API_KEY"] ?? "",
                         model: ProcessInfo.processInfo.environment["MPET_MODEL"] ?? "gpt-4o-mini")
    }
    let path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/mpet/soul.json")
    struct C: Codable { let llm: LLMConfig }
    return try JSONDecoder().decode(C.self, from: Data(contentsOf: path)).llm
}

let args = CommandLine.arguments.dropFirst()
guard let cmd = args.first else {
    print("usage: soulctl status|chat <text>|event <kind>|sense <kind> <priority>|probe")
    exit(1)
}

if cmd == "probe" {
    let sem = DispatchSemaphore(value: 0)
    var exitCode: Int32 = 0
    Task {
        do {
            let config = try SoulConfig_loadForCtl()
            let report = await CapabilityProbe.run(provider: OpenAILLMClient(config: config))
            print(String(data: try JSONEncoder().encode(report), encoding: .utf8)!)
            print(report.usable ? "✅ 端点可用（工具调用+参数保真）" : "❌ 端点不合格：\(report.notes)")
            exitCode = report.usable ? 0 : 1
        } catch {
            FileHandle.standardError.write(Data("probe 失败：\(error)\n".utf8))
            exitCode = 2
        }
        sem.signal()
    }
    sem.wait()
    exit(exitCode)
}

let sockPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/mpet/soul.sock").path
let conn = NWConnection(to: .unix(path: sockPath), using: .tcp)
let done = DispatchSemaphore(value: 0)
var codec = LineCodec()

func send(_ m: PeripheralMessage) {
    conn.send(content: try! LineCodec.encode(m), completion: .contentProcessed { _ in })
}

func receiveLoop() {
    conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isDone, _ in
        if let data = data, let msgs = try? codec.feed(data) {
            for m in msgs {
                switch m {
                case .helloOK(_, let v): print("connected soul v\(v)")
                case .chatDelta(let t): print(t, terminator: ""); fflush(stdout)
                case .chatDone: print(""); done.signal()
                case .statusOK(let f): print(f); done.signal()
                case .directive(let kind, let payload): print("← [\(kind)] \(payload)")
                case .pong: print("pong"); done.signal()
                default: break
                }
            }
        }
        if isDone { done.signal() } else { receiveLoop() }
    }
}

conn.start(queue: .global())
receiveLoop()
send(.hello(role: "ctl", name: "soulctl", proto: 1))

switch cmd {
case "status":
    send(.status)
case "chat":
    send(.chatUser(text: args.dropFirst().joined(separator: " ")))
case "event":
    send(.event(kind: args.dropFirst().first ?? "click", payload: [:]))
    DispatchQueue.global().asyncAfter(deadline: .now() + 3) { done.signal() }
case "sense":
    let kind = args.dropFirst().first ?? "demo"
    let pr = PerceptPriority(rawValue: args.dropFirst(2).first ?? "nudge") ?? .nudge
    send(.senseEvent(Percept(kind: kind, priority: pr,
                             payload: ["title": .string("测试事件 \(kind)")],
                             actions: [PerceptAction(id: "look", label: "看看")], at: Date())))
    DispatchQueue.global().asyncAfter(deadline: .now() + 8) { done.signal() }
default:
    print("unknown command")
    exit(1)
}

_ = done.wait(timeout: .now() + 120)
