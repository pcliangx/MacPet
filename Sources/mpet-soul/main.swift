import Foundation
import SoulCore

let clock = SystemClock()
let config: SoulConfig
do { config = try SoulConfig.load() } catch {
    FileHandle.standardError.write(Data("配置缺失：写 ~/.config/mpet/soul.json 或设 MPET_BASE_URL/MPET_API_KEY/MPET_MODEL\n".utf8))
    exit(2)
}

let supportDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/mpet")
let soulDir = supportDir.appendingPathComponent("soul/state")
try? FileManager.default.createDirectory(at: soulDir, withIntermediateDirectories: true,
                                         attributes: [.posixPermissions: 0o700])
try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: supportDir.path)

let store = StateStore(directory: soulDir, clock: clock)
var state = store.load()
let perceptLog = PerceptLog(clock: clock)
let wakePolicy = WakePolicy(clock: clock, nudgeBudgetPerHour: config.nudgeBudgetPerHour)
let registry = ToolRegistry()
let provider = OpenAILLMClient(config: config.llm)

var server: SocketServer!
let sink: DirectiveSink = { m in
    server.broadcast(m)
    if case .directive(let kind, let payload) = m {
        print("🦊 [\(kind)] \(payload)")
    }
}
await registry.registerCoreTools(sink: sink)
let mind = Mind(provider: provider, tools: registry, genome: .default, clock: clock)

func currentAttention() -> Attention {
    AttentionResolver.resolve(PresenceSensorMac.snapshot(watched: Set(config.watchedBundleIDs)))
}
func currentMood(attention: Attention) -> Mood {
    let since = state.lastInteractionAt.map { clock.now.timeIntervalSince($0) } ?? .infinity
    return MoodEngine.mood(.init(attention: attention,
                                 hour: Calendar.current.component(.hour, from: clock.now),
                                 secondsSinceInteraction: since))
}
func handlePercept(_ p: Percept) {
    perceptLog.add(p)
    let attention = currentAttention()
    let mood = currentMood(attention: attention)
    for d in ReflexArc.directives(for: p, attention: attention, mood: mood) { sink(d) }
    Task {
        if await wakePolicy.shouldWake(for: p) {
            await mind.wake(reason: p.kind, mood: mood, attention: attention,
                            recent: perceptLog.recent(limit: 8))
        }
    }
}

server = try SocketServer(socketPath: supportDir.appendingPathComponent("soul.sock").path) { msg, reply in
    switch msg {
    case .hello(let role, let name, _):
        print("👋 外设接入：\(role)/\(name)")
        reply(.helloOK(proto: 1, soulVersion: SoulCoreInfo.version))
    case .ping: reply(.pong)
    case .status:
        let att = currentAttention()
        reply(.statusOK([
            "mood": .string(currentMood(attention: att).rawValue),
            "attention": .string(att.rawValue),
            "stage": .string("baby"),
            "version": .string(SoulCoreInfo.version),
        ]))
    case .chatUser(let text):
        state.lastInteractionAt = clock.now; try? store.save(state)
        let att = currentAttention()
        Task {
            do {
                try await mind.chat(text, mood: currentMood(attention: att), attention: att,
                                    recent: perceptLog.recent(limit: 8),
                                    onDelta: { reply(.chatDelta(text: $0)) })
            } catch { reply(.directive(kind: "error", payload: ["message": .string("\(error)")])) }
            reply(.chatDone)
        }
    case .event(let kind, let payload):
        state.lastInteractionAt = clock.now; try? store.save(state)
        handlePercept(Percept(kind: "body.\(kind)", priority: .nudge, payload: payload, at: clock.now))
    case .senseEvent(let p):
        handlePercept(p)
    case .actionInvoke(let eventId, let actionId):
        print("🎯 affordance 回调：\(eventId)/\(actionId)（M1 起路由给来源插件）")
    case .bye: break
    default: break
    }
}
server.start()
print("mpet-soul \(SoulCoreInfo.version) ｜ soul.sock 就绪 ｜ 模型=\(config.llm.model)")
// stdout 重定向到文件时 libc 默认全缓冲；显式刷新让日志即时可见（常驻进程不会自然 flush）
fflush(stdout)
// 保持灵魂常驻；NWListener 回调在自己的 global 队列上运行，主任务永久挂起即可
await withUnsafeContinuation { (_: UnsafeContinuation<Void, Never>) in }
