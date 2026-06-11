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
let memoryDir = supportDir.appendingPathComponent("soul/memory")
try? FileManager.default.createDirectory(at: memoryDir, withIntermediateDirectories: true)
let memoryStore = MemoryStore(directory: memoryDir)
let roomDir = supportDir.appendingPathComponent("soul/room")
try? FileManager.default.createDirectory(at: roomDir, withIntermediateDirectories: true)
let roomStore = PetRoomStore(directory: roomDir)
let projectDir = supportDir.appendingPathComponent("soul/projects")
try? FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
let projectStore = PetProjectStore(directory: projectDir)
let friendsDir = supportDir.appendingPathComponent("soul/friends")
try? FileManager.default.createDirectory(at: friendsDir, withIntermediateDirectories: true)
let friendStore = FriendStore(directory: friendsDir)
let daemon = DaemonSoul(
    store: store, growthStore: growthStore, memoryStore: memoryStore,
    roomStore: roomStore, projectStore: projectStore, friendStore: friendStore,
    clock: clock,
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
await MemoryTools.register(registry: registry, memoryStore: memoryStore)

// M7: 孵化即领身份密钥（spec §9.1）
let identity = await daemon.ensureIdentity(petName: Genome.default.petName, species: Genome.default.species)
print("🪪 宠物身份就绪：\(identity.petName)（公钥 \(identity.publicKey.prefix(8).map { String(format: "%02x", $0) }.joined())…）")

// M8: 广场/安全/徽章 stores（spec §9.5/§9.6）
let plazaDir = supportDir.appendingPathComponent("soul/plaza")
let safetyDir = supportDir.appendingPathComponent("soul/safety")
let badgeDir = supportDir.appendingPathComponent("soul/badges")
await daemon.attachSocialStores(
    plaza: PlazaSightingStore(directory: plazaDir),
    safety: SocialSafety(directory: safetyDir),
    badges: BadgeCollectionStore(directory: badgeDir)
)

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
            await daemon.recordChat()
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
        // M6: drift personality at day boundary
        await daemon.recordDayInteractions()
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
            // M6: attention seeking got a response → record it
            await daemon.recordAttentionResponse()
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

        // M6: 检查里程碑
        let newMilestones = await daemon.checkMilestones()
        for m in newMilestones {
            sink(.directive(kind: "speak", payload: ["text": .string("我刚刚达成了「\(m.name)」！")]))
        }
        if let anniversary = await daemon.checkAnniversary() {
            sink(.directive(kind: "speak", payload: ["text": .string(anniversary)]))
        }

        // M8: 检查徽章解锁
        let newBadges = await daemon.checkBadges()
        for b in newBadges {
            sink(.directive(kind: "speak", payload: ["text": .string("我得到了「\(b.name)」徽章！\(b.description)")]))
        }

        // 做梦：深夜时段（2-4 点）且还没做过梦
        let hour = Calendar.current.component(.hour, from: Date())
        // M6: record late night activity (23:00–5:00)
        if hour >= 23 || hour < 5 {
            await daemon.recordLateNightActivity()
        }
        if (2...4).contains(hour) {
            let dream = await daemon.performDream()
            if !dream.newSemantics.isEmpty || !dream.milestones.isEmpty {
                print("💭 做梦：蒸馏了 \(dream.newSemantics.count) 条语义记忆，发现 \(dream.milestones.count) 个里程碑")
            }
            // Save diary
            let diaryDir = supportDir.appendingPathComponent("soul/diary")
            try? DiaryWriter.save(entry: dream.diaryEntry, date: Date(), to: diaryDir)
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
