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
let daemon = DaemonSoul(
    store: store, clock: clock,
    watchedBundleIDs: config.watchedBundleIDs,
    nudgeBudgetPerHour: config.nudgeBudgetPerHour,
    genome: .default
)
let registry = ToolRegistry()
let provider = OpenAILLMClient(config: config.llm)
let mind = Mind(provider: provider, tools: registry, genome: .default, clock: clock)

var server: SocketServer!
let sink: DirectiveSink = { m in
    server.broadcast(m)
    if case .directive(let kind, let payload) = m {
        print("🦊 [\(kind)] \(payload)")
    }
}
await registry.registerCoreTools(sink: sink)

func currentAttention() -> Attention {
    AttentionResolver.resolve(PresenceSensorMac.snapshot(watched: Set(config.watchedBundleIDs)))
}

func handlePercept(_ p: Percept) async {
    let (directives, shouldWakeAlert) = await daemon.handlePercept(p)
    for d in directives { sink(d) }
    if shouldWakeAlert {
        let att = currentAttention()
        await daemon.recomputeMood(attention: att)
        let mood = await daemon.currentMood
        let recent = await daemon.recentPercepts(limit: 8)
        await mind.wake(reason: p.kind, mood: mood, attention: att, recent: recent)
    } else if p.priority == .nudge {
        let shouldWake = await daemon.shouldWake(for: p)
        if shouldWake {
            let att = currentAttention()
            await daemon.recomputeMood(attention: att)
            let mood = await daemon.currentMood
            let recent = await daemon.recentPercepts(limit: 8)
            await mind.wake(reason: p.kind, mood: mood, attention: att, recent: recent)
        }
    }
}

server = try SocketServer(socketPath: supportDir.appendingPathComponent("soul.sock").path) { msg, reply in
    Task {
        switch msg {
        case .hello(let role, let name, _):
            print("👋 外设接入：\(role)/\(name)")
            reply(.helloOK(proto: 1, soulVersion: SoulCoreInfo.version))
        case .ping: reply(.pong)
        case .status:
            let att = currentAttention()
            await daemon.recomputeMood(attention: att)
            let snapshot = await daemon.statusSnapshot(attention: att)
            reply(.statusOK(snapshot))
        case .chatUser(let text):
            await daemon.noteInteraction()
            let att = currentAttention()
            await daemon.recomputeMood(attention: att)
            let mood = await daemon.currentMood
            let recent = await daemon.recentPercepts(limit: 8)
            do {
                try await mind.chat(text, mood: mood, attention: att, recent: recent,
                                    onDelta: { reply(.chatDelta(text: $0)) })
            } catch {
                reply(.directive(kind: "error", payload: ["message": .string("\(error)")]))
            }
            reply(.chatDone)
        case .event(let kind, let payload):
            await daemon.handleEvent(kind: kind, payload: payload)
            let att = currentAttention()
            await daemon.recomputeMood(attention: att)
            await handlePercept(Percept(kind: "body.\(kind)", priority: .nudge, payload: payload, at: clock.now))
        case .senseEvent(let p):
            await handlePercept(p)
        case .actionInvoke(let eventId, let actionId):
            print("🎯 affordance 回调：\(eventId)/\(actionId)")
        case .bye: break
        default: break
        }
    }
}
server.start()
print("mpet-soul \(SoulCoreInfo.version) ｜ soul.sock 就绪 ｜ 模型=\(config.llm.model)")
fflush(stdout)
await withUnsafeContinuation { (_: UnsafeContinuation<Void, Never>) in }
