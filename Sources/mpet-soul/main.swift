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
let growthDir = supportDir.appendingPathComponent("soul/growth")
try? FileManager.default.createDirectory(at: growthDir, withIntermediateDirectories: true)
let growthStore = GrowthStateStore(directory: growthDir, clock: clock)
let daemon = DaemonSoul(
    store: store, growthStore: growthStore, clock: clock,
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
            await daemon.addBond(.chat)
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
            // M2: 身体不在线时 alert 走系统通知
            if p.priority == .alert {
                let title = p.payload["title"]?.stringValue ?? p.kind
                AbsentBodyNotifier.notify(title: "🦊 mpet", body: title)
            }
            await handlePercept(p)
        case .fuelReport(_, let raw):
            await daemon.applyFuelReport(raw: raw)
        case .actionInvoke(let eventId, let actionId):
            print("🎯 affordance 回调：\(eventId)/\(actionId)")
        case .bye: break
        default: break
        }
    }
}
// M2: 定期 lifecycle 检查（每 60 秒）
Task {
    while true {
        try? await Task.sleep(nanoseconds: 60_000_000_000)  // 60 秒
        await daemon.dailyRolloverIfNeeded()
        let snap = PresenceSensorMac.snapshot(watched: Set(config.watchedBundleIDs))
        let idleMinutes = Int(snap.idleSeconds / 60)
        await daemon.updateLifecycle(idleMinutes: idleMinutes)

        // 检查回归问候
        if let greeting = await daemon.generateReturnGreeting() {
            sink(.directive(kind: "speak", payload: ["text": .string(greeting)]))
        }

        // 检查求关注
        if let seek = await daemon.checkAttentionSeeking(idleMinutes: idleMinutes) {
            sink(.directive(kind: "speak", payload: ["text": .string(seek.text)]))
            sink(.directive(kind: "emote", payload: ["animation": .string(seek.emote)]))
        }

        // 检查心跳
        let hb = await daemon.checkHeartbeat()
        if hb.shouldWake {
            if let emote = hb.emote {
                sink(.directive(kind: "emote", payload: ["animation": .string(emote)]))
            }
            if let speech = hb.speech {
                sink(.directive(kind: "speak", payload: ["text": .string(speech)]))
            }
        }

        // 重新计算 mood
        let att = currentAttention()
        await daemon.recomputeMood(attention: att)
    }
}

server.start()
print("mpet-soul \(SoulCoreInfo.version) ｜ soul.sock 就绪 ｜ 模型=\(config.llm.model)")
fflush(stdout)
await withUnsafeContinuation { (_: UnsafeContinuation<Void, Never>) in }
