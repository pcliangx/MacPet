import Foundation

/// M1 修复 #1：daemon 可变状态 actor 化（消除 socket 并发数据竞争）
public actor DaemonSoul {
    private let store: StateStore
    private let clock: SoulClock
    private let watchedBundleIDs: Set<String>
    private let perceptLog: PerceptLog
    private let wakePolicy: WakePolicy
    private var lifecyclePhase: LifecyclePhase = .active
    private let heartbeat: HeartbeatScheduler
    private let attentionSeeker: AttentionSeeker
    private var state: SoulState
    private var lastPresenceCheck: Date
    public private(set) var interactionCount: Int = 0

    // ── Growth (M3) ──
    private var growthState: GrowthState
    private let growthStore: GrowthStateStore

    // ── Memory (M4) ──
    private let memoryStore: MemoryStore

    // ── Room (M6) ──
    private let roomStore: PetRoomStore

    // ── Projects (M6) ──
    private let projectStore: PetProjectStore

    // ── Milestones (M6) ──
    private var milestones: [Milestone] = []

    // ── Personality (M6) ──
    private var personalityTraits: PersonalityTraits = .default
    private var todayInteractions = PersonalityDrift.DayInteractions()

    // ── Social (M7) ──
    private var identity: PetIdentity?
    private let friendStore: FriendStore

    public init(store: StateStore, growthStore: GrowthStateStore, memoryStore: MemoryStore,
                roomStore: PetRoomStore, projectStore: PetProjectStore, friendStore: FriendStore, clock: SoulClock,
                watchedBundleIDs: [String], nudgeBudgetPerHour: Int, genome: Genome) {
        self.store = store; self.clock = clock
        self.watchedBundleIDs = Set(watchedBundleIDs)
        self.perceptLog = PerceptLog(clock: clock)
        self.wakePolicy = WakePolicy(clock: clock, nudgeBudgetPerHour: nudgeBudgetPerHour)
        self.heartbeat = HeartbeatScheduler(clock: clock)
        self.attentionSeeker = AttentionSeeker(budgetPerHour: 2)
        self.state = store.load()
        self.lastPresenceCheck = clock.now
        self.growthStore = growthStore
        self.growthState = growthStore.load()
        self.memoryStore = memoryStore
        self.roomStore = roomStore
        self.projectStore = projectStore
        self.friendStore = friendStore
    }

    public func noteInteraction() {
        state.lastInteractionAt = clock.now
        interactionCount += 1
        try? store.save(state)
    }
    public var lastInteractionAt: Date? { state.lastInteractionAt }

    public func recomputeMood(attention: Attention) {
        let since = state.lastInteractionAt.map { clock.now.timeIntervalSince($0) } ?? .infinity
        let hour = Calendar.current.component(.hour, from: clock.now)
        let mood = MoodEngine.mood(.init(attention: attention, hour: hour, secondsSinceInteraction: since))
        state.mood = mood
        try? store.save(state)
    }
    public var currentMood: Mood { state.mood }

    public var currentPhase: LifecyclePhase { lifecyclePhase }

    public func updateLifecycle(idleMinutes: Int) {
        let hour = Calendar.current.component(.hour, from: clock.now)
        let wasAsleep = lifecyclePhase == .asleep
        lifecyclePhase = LifecyclePhase.resolve(hour: hour, idleMinutes: idleMinutes, wasAsleep: wasAsleep)
        let since = state.lastInteractionAt.map { clock.now.timeIntervalSince($0) } ?? .infinity
        let attention: Attention
        if idleMinutes > 180 { attention = .away }
        else if idleMinutes < 5 { attention = .attending }
        else { attention = .elsewhere }
        let mood = MoodEngine.moodV2(.init(attention: attention, hour: hour,
            secondsSinceInteraction: since, phase: lifecyclePhase))
        state.mood = mood
        try? store.save(state)
    }

    public func checkHeartbeat() async -> (shouldWake: Bool, emote: String?, speech: String?) {
        let idle = idleMinutesFromState()
        guard await heartbeat.shouldFire(lastInteractionMinutesAgo: idle) else { return (false, nil, nil) }
        let (emote, speech) = IdleActions.pick(phase: lifecyclePhase, mood: state.mood)
        return (true, emote, speech)
    }

    public func checkAttentionSeeking(idleMinutes: Int) -> (text: String, emote: String)? {
        guard attentionSeeker.shouldSeekAttention(idleMinutes: idleMinutes, phase: lifecyclePhase) else { return nil }
        attentionSeeker.consumeAttention()
        return (AttentionSeeker.pickAction(mood: state.mood), AttentionSeeker.pickEmote(mood: state.mood))
    }

    public func generateReturnGreeting() -> String? {
        guard lifecyclePhase == .returning else { return nil }
        let minutes = idleMinutesFromState()
        return ReturnDetector.greeting(absenceMinutes: minutes, phase: lifecyclePhase, mood: state.mood)
    }

    private func idleMinutesFromState() -> Int {
        guard let last = state.lastInteractionAt else { return 999 }
        return Int(clock.now.timeIntervalSince(last) / 60)
    }

    public func handleEvent(kind: String, payload: [String: JSONValue]) {
        noteInteraction()
        let percept = Percept(kind: "body.\(kind)", priority: .nudge, payload: payload, at: clock.now)
        perceptLog.add(percept)
    }

    public func handlePercept(_ p: Percept) -> (directives: [PeripheralMessage], shouldWake: Bool) {
        perceptLog.add(p)
        let snap = PresenceSnapshot(frontmostBundleID: nil, idleSeconds: 0, watchedBundleIDs: watchedBundleIDs)
        let attention = AttentionResolver.resolve(snap)
        let mood = state.mood
        let directives = ReflexArc.directives(for: p, attention: attention, mood: mood)
        return (directives, p.priority == .alert)
    }

    public func recentPercepts(limit: Int) -> [Percept] { perceptLog.recent(limit: limit) }

    public func shouldWake(for p: Percept) async -> Bool { await wakePolicy.shouldWake(for: p) }

    public func statusSnapshot(attention: Attention) -> [String: JSONValue] {
        ["mood": .string(state.mood.rawValue),
         "attention": .string(attention.rawValue),
         "stage": .string("\(growthState.stage)"),
         "totalXP": .number(Double(growthState.totalXP)),
         "streakDays": .number(Double(growthState.streakDays)),
         "version": .string(SoulCoreInfo.version),
         "lastInteraction": state.lastInteractionAt.map { .number($0.timeIntervalSince1970) } ?? .null,
         "personality": .string(PersonalityDrift.describe(personalityTraits)),
         "roomItems": .number(Double(roomStore.itemCount)),
         "roomGifts": .number(Double(roomStore.giftCount)),
         "friends": .number(Double(friendStore.friendCount())),
         "rivals": .number(Double(friendStore.rivalCount())),
         "hasIdentity": .bool(identity != nil)]
    }

    // ── Growth (M3) ──

    public var currentGrowth: GrowthState { growthState }

    public func applyXP(_ amount: Int) {
        growthState.todayXP += amount
        growthState.totalXP += amount
        let newStage = GrowthState.stageForXP(growthState.totalXP)
        if newStage > growthState.stage {
            growthState.stage = newStage
            // TODO: emit evolve directive (handled by caller)
        }
        try? growthStore.save(growthState)
    }

    public func addBond(_ interaction: EconomyEngine.BondInteraction) {
        growthState.bond += EconomyEngine.bondGain(for: interaction)
        try? growthStore.save(growthState)
    }

    public func applyFuelReport(raw: Double) {
        let xp = EconomyEngine.calcXPGain(
            fuelRaw: raw,
            streakMultiplier: EconomyEngine.streakMultiplier(days: growthState.streakDays),
            todayXPSoFar: growthState.todayXP
        )
        if xp > 0 { applyXP(xp) }
    }

    public func dailyRolloverIfNeeded() {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        let today = f.string(from: clock.now)
        guard today != growthState.todayDate else { return }
        // Update streak
        if let lastDay = growthState.lastActiveDay.isEmpty ? nil : growthState.lastActiveDay {
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            if let lastDate = df.date(from: lastDay),
               let expected = Calendar.current.date(byAdding: .day, value: 1, to: lastDate),
               f.string(from: expected) == today {
                growthState.streakDays += 1
            } else {
                growthState.streakDays = 1
            }
        } else {
            growthState.streakDays = 1
        }
        growthState.lastActiveDay = growthState.todayDate
        growthState.todayDate = today
        growthState.todayXP = 0
        try? growthStore.save(growthState)
    }

    public func growthSnapshot() -> [String: JSONValue] {
        ["stage": .string("\(growthState.stage)"),
         "totalXP": .number(Double(growthState.totalXP)),
         "todayXP": .number(Double(growthState.todayXP)),
         "bond": .number(Double(growthState.bond)),
         "streakDays": .number(Double(growthState.streakDays)),
         "progress": .number(growthState.progressToNext)]
    }

    // ── Memory (M4) ──

    public var memoryCount: Int { memoryStore.count() }

    public func addMemory(_ memory: Memory) { memoryStore.add(memory) }

    public func recallMemories(query: String, limit: Int = 5) -> [Memory] {
        MemorySearch.search(query: query, in: memoryStore.getAll(), limit: limit)
    }

    public func performDream() -> (diaryEntry: String, newSemantics: [Memory], milestones: [Memory]) {
        let episodic = memoryStore.getAll().filter { $0.kind == .episodic }
        let newSemantics = DreamEngine.distill(episodic: episodic)
        let milestones = DreamEngine.checkMilestones(growthState: growthState)
        // Add new memories
        newSemantics.forEach { memoryStore.add($0) }
        milestones.forEach { memoryStore.add($0) }
        // Write diary
        let entry = DiaryWriter.writeEntry(date: clock.now, events: episodic, mood: state.mood, stage: growthState.stage)
        return (entry, newSemantics, milestones)
    }

    public func exportArchive() throws -> Data {
        try ArchiveExporter.export(memories: memoryStore.getAll(), growth: growthState, soul: state)
    }

    public func importArchive(_ data: Data) throws {
        let archive = try ArchiveExporter.importArchive(data)
        growthState = archive.growthState
        state = archive.soulState
        // Replace memories
        for m in memoryStore.getAll() { memoryStore.delete(id: m.id) }
        for m in archive.memories { memoryStore.add(m) }
        try? growthStore.save(growthState)
        try? store.save(state)
    }

    /// Get top memories for persona prompt
    public func topMemoriesForPrompt(query: String = "", limit: Int = 3) -> [Memory] {
        MemorySearch.search(query: query, in: memoryStore.getAll(), limit: limit)
    }

    // ── Room (M6) ──

    public func addItemToRoom(name: String, description: String) -> PetRoom.RoomItem {
        roomStore.addItem(name: name, description: description)
    }

    public func addGiftToRoom(description: String, forOwner: Bool) -> PetRoom.Gift {
        roomStore.addGift(description: description, forOwner: forOwner)
    }

    public var roomItemCount: Int { roomStore.itemCount }

    // ── Projects (M6) ──

    public func addProject(_ project: PetProject) { projectStore.add(project) }

    public func updateProjectProgress(id: String, progress: Double) {
        projectStore.updateProgress(id: id, progress: progress)
    }

    public var activeProjects: [PetProject] { projectStore.getAll().filter { $0.status == .active } }

    // ── Milestones (M6) ──

    public func checkMilestones() -> [Milestone] {
        let new = MilestoneTracker.detectNewMilestones(growth: growthState, bond: growthState.bond, existing: milestones)
        milestones.append(contentsOf: new)
        return new
    }

    public func checkAnniversary() -> String? {
        guard let m = MilestoneTracker.checkAnniversary(milestones: milestones) else { return nil }
        return MilestoneTracker.anniversaryGreeting(milestone: m)
    }

    // ── Personality (M6) ──

    public var currentPersonality: PersonalityTraits { personalityTraits }

    public var personalityDescription: String { PersonalityDrift.describe(personalityTraits) }

    public func recordDayInteractions() {
        personalityTraits = PersonalityDrift.drift(traits: personalityTraits, interactions: todayInteractions)
        todayInteractions = PersonalityDrift.DayInteractions()
    }

    public func recordChat() { todayInteractions.chatCount += 1 }

    public func recordLateNightActivity() { todayInteractions.lateNightActivity = true }

    public func recordAttentionResponse() { todayInteractions.attentionResponses += 1 }

    // ── Auth (M6) ──

    public func authorizeTool(name: String, tier: ToolTier) -> Bool {
        // Simplified: real check needs ToolRegistry lookup for ToolSpec
        return true
    }

    // ── Identity (M7) ──

    public func ensureIdentity(petName: String, species: String) -> PetIdentity {
        if let id = identity { return id }
        let id = PetIdentity.generate(petName: petName, species: species)
        identity = id
        return id
    }

    public var petCard: PetCard? { identity?.card() }
    public var hasIdentity: Bool { identity != nil }

    // ── Friends (M7) ──

    public func addFriend(from ticket: FriendTicket) -> Friend { friendStore.addFriend(from: ticket) }
    public func makeRival(id: String) { friendStore.setRival(id: id) }
    public func friendCount() -> Int { friendStore.friendCount() }
    public func rivalCount() -> Int { friendStore.rivalCount() }
    public func getAllFriends() -> [Friend] { friendStore.getAll() }

    // ── Battle (M7) ──

    public func initiateBattle(friendId: String, seed: Int) -> BattleResult? {
        guard let friend = friendStore.get(id: friendId), let myCard = petCard else { return nil }
        let result = BattleEngine.resolve(
            challenger: myCard, defender: friend.card,
            challengerTraits: personalityTraits, defenderTraits: .default, seed: seed
        )
        let won = result.winnerKey == myCard.publicKey
        friendStore.updateBattle(id: friendId, won: won)
        return result
    }

    // ── Social snapshot (M7) ──

    public func socialSnapshot() -> [String: JSONValue] {
        ["friends": .number(Double(friendStore.friendCount())),
         "rivals": .number(Double(friendStore.rivalCount())),
         "hasIdentity": .bool(identity != nil)]
    }

    // ── Archive (M7: 含身份密钥) ──

    public func exportArchiveWithIdentity() throws -> Data {
        try ArchiveExporter.export(memories: memoryStore.getAll(), growth: growthState, soul: state,
                                    identity: identity, friends: friendStore.getAll())
    }

    public func importArchiveWithIdentity(_ data: Data) throws {
        let archive = try ArchiveExporter.importArchive(data)
        growthState = archive.growthState
        state = archive.soulState
        if let id = archive.identity { identity = id }
        for m in memoryStore.getAll() { memoryStore.delete(id: m.id) }
        for m in archive.memories { memoryStore.add(m) }
        try? growthStore.save(growthState)
        try? store.save(state)
    }

    // ── Plaza & Safety & Ladder & Badges (M8) ──

    private var plazaStore: PlazaSightingStore?
    private var safety: SocialSafety?
    private var badgeStore: BadgeCollectionStore?

    public func attachSocialStores(plaza: PlazaSightingStore, safety: SocialSafety, badges: BadgeCollectionStore) {
        self.plazaStore = plaza
        self.safety = safety
        self.badgeStore = badges
    }

    /// 阶段门控（spec §9.6）：少年解锁串门；成年解锁广场与天梯
    public var canVisitFriends: Bool { growthState.stage >= .juvenile }
    public var canUsePlaza: Bool { growthState.stage >= .adult }
    public var canUseLadder: Bool { FriendLadder.isUnlocked(stage: growthState.stage) }

    /// 是否允许与某节点互动（社交总开关+拉黑+仅好友模式综合）
    public func allowsSocialInteraction(nodeId: String) -> Bool {
        guard let safety else { return false }
        let isFriend = friendStore.get(id: nodeId) != nil
        return safety.allowsInteraction(nodeId: nodeId, isFriend: isFriend)
    }

    /// 记录广场见闻（已过注入防御）
    public func recordPlazaSighting(card: PetCard, snippet: String) {
        guard canUsePlaza, let plazaStore else { return }
        let safe = PlazaGossip.sanitizeSnippet(snippet)
        plazaStore.add(PlazaSighting(card: card, snippet: safe))
    }

    /// 它回来讲的见闻
    public func plazaStory() -> String? {
        guard let plazaStore else { return nil }
        return PlazaGossip.generateStory(sightings: plazaStore.recent(limit: 3))
    }

    /// 检查徽章解锁。返回新解锁的徽章。
    public func checkBadges() -> [Badge] {
        guard let badgeStore else { return [] }
        let totalWins = friendStore.getAll().reduce(0) { $0 + $1.battleRecord.wins }
        return badgeStore.checkUnlocks(
            friendCount: friendStore.friendCount(),
            rivalCount: friendStore.rivalCount(),
            totalWins: totalWins,
            sightingCount: plazaStore?.count ?? 0
        )
    }

    /// 朋友圈天梯（成年解锁；未解锁返回空）
    public func friendLadder() -> [FriendLadder.Entry] {
        guard canUseLadder else { return [] }
        let myWins = friendStore.getAll().reduce(0) { $0 + $1.battleRecord.wins }
        let myLosses = friendStore.getAll().reduce(0) { $0 + $1.battleRecord.losses }
        let myName = identity?.petName ?? "我"
        return FriendLadder.ranking(friends: friendStore.getAll(),
                                     includeSelf: (name: myName, wins: myWins, losses: myLosses))
    }

    // ── Plugins (M9: 礼物仪式 + 安装) ──

    private var permissionStore: PluginPermissionStore?
    private var installedPlugins: [String: PluginManifest] = [:]

    public func attachPluginStores(permissions: PluginPermissionStore) {
        self.permissionStore = permissions
    }

    /// 安装插件（已通过权限确认后调用）。返回礼物仪式。
    public func installPlugin(manifest: PluginManifest, grantedPermissions: [PluginPermission]) -> GiftCeremony.Ceremony? {
        let issues = manifest.validate()
        guard issues.isEmpty else { return nil }
        installedPlugins[manifest.name] = manifest
        if let permissionStore {
            for p in grantedPermissions { permissionStore.grant(plugin: manifest.name, permission: p) }
        }
        let ceremony = GiftCeremony.perform(manifest: manifest, petName: identity?.petName ?? "宠物")
        // 礼物进日记素材（spec §10.7：当晚写进日记）
        memoryStore.add(Memory(kind: .episodic, content: ceremony.diaryNote, importance: 4))
        return ceremony
    }

    /// 卸载插件 = 收起玩具（不悲情）
    public func uninstallPlugin(name: String) -> String? {
        guard let manifest = installedPlugins.removeValue(forKey: name) else { return nil }
        permissionStore?.revokeAll(plugin: name)
        let toyName = manifest.personaHints?.toyName ?? manifest.displayName
        return GiftCeremony.putAway(toyName: toyName)
    }

    public var installedPluginCount: Int { installedPlugins.count }
    public func pluginManifest(name: String) -> PluginManifest? { installedPlugins[name] }
}
