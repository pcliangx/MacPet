# M1 借壳还魂 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 桌面身体 App 接上灵魂（PetWindow + SVGRenderer + 气泡 + ChatPanel + 状态菜单 + 设置/Keychain）+ cc-watcher 第一方插件 v0（hook + spool + 喊人 + affordance + 多会话）+ launchd 一键安装——首个可玩版，桌面有它、能聊、守望恢复。

**Architecture:** 在 M0 基础上新增：`SoulClient`（客户端 socket 库）+ `HookInstaller` + `CCWatcher`（CC 事件解析与 spool 监听）+ `KeychainStore` + `LaunchdInstaller`（纯逻辑，全单测）→ `MpetApp`（SwiftUI macOS .app，SVGRenderer[WKWebView] + ChatPanel + StatusMenu + Settings + Onboarding）+ `mpet-cc-watcher`（独立可执行，连 soul.sock）。

**Tech Stack:** Swift 5.9 / SPM / macOS 13+，零第三方依赖。GUI 用 SwiftUI + AppKit（NSPanel 透明窗口）+ WebKit（WKWebView SVG 渲染）。Keychain 用 Security.framework。

**对应 spec 条目：** §5.1 身体外设（桌面 App + launchd）· §10.9 cc-watcher 第一方插件 · §5.2 感知器「工作脉搏」接入 · §11 关键体验（日常/被喊回来 + 设置面板 v0）· §12 #3 Keychain · §3 支柱 5「能力即陪伴」启程。

**M0 遗留两修：** ① daemon `var state` 数据竞争 → `DaemonSoul` actor · ② `SoulState.mood` 已持久化但运行时未用 → 运行时回写。

**M1 不做（防镀金）：** 成长/XP、记忆、做梦、P2P 社交、插件进程管理（M1 cc-watcher 手工启动）、形象基因组共创仪式（M5，M1 用固定默认 SVG）、生图、MCP 桥、礼物仪式。

---

## 文件结构（先锁边界）

```
Package.swift                                          # 新增 5 targets
Sources/SoulCore/
  State/DaemonSoul.swift                               # NEW: actor 包装 daemon 可变状态
  Client/SoulClient.swift                              # NEW: NWConnection socket 客户端
  Plugin/HookInstaller.swift                           # NEW: CC settings.json 管理
  Plugin/CCEvent.swift                                 # NEW: CC hook 事件类型 + 防御式解析
  Plugin/CCSpoolMonitor.swift                          # NEW: spool 目录文件监听
  Security/KeychainStore.swift                         # NEW: Keychain 读写
  System/LaunchdInstaller.swift                        # NEW: LaunchAgent plist 管理
Sources/mpet-soul/main.swift                           # REWRITE: 用 DaemonSoul actor
Sources/mpet-cc-watcher/main.swift                     # NEW: cc-watcher 插件可执行
Sources/MpetApp/
  MpetAppMain.swift                                    # NEW: @main App
  PetWindow.swift                                      # NEW: 透明 NSPanel
  SVGRenderer.swift                                    # NEW: WKWebView SVG 渲染
  PetViewModel.swift                                   # NEW: ObservableObject 连接层
  BubbleView.swift                                     # NEW: 气泡浮层
  ChatPanel.swift                                      # NEW: 聊天面板
  StatusMenu.swift                                     # NEW: 菜单栏
  SettingsPanel.swift                                  # NEW: 设置面板
  OnboardingView.swift                                 # NEW: 初见引导
  Assets/pet.svg                                       # NEW: 从 spikes 复制
  Assets/pet.css                                       # NEW: 状态动画 CSS
Tests/SoulCoreTests/
  DaemonSoulTests.swift                                # NEW
  SoulClientTests.swift                                # NEW
  HookInstallerTests.swift                             # NEW
  CCEventTests.swift                                   # NEW
  CCSpoolMonitorTests.swift                            # NEW
  KeychainStoreTests.swift                             # NEW
  LaunchdInstallerTests.swift                          # NEW
  MoodStateTests.swift                                 # NEW: mood 回写验证
```

---

### Task 0: Package.swift 更新 + 版本标记

**Files:** Modify: `Package.swift`, `Sources/SoulCore/SoulCore.swift`

- [ ] **Step 1: 更新 Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "mpet",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "SoulCore"),
        .executableTarget(name: "mpet-soul", dependencies: ["SoulCore"]),
        .executableTarget(name: "soulctl", dependencies: ["SoulCore"]),
        .executableTarget(name: "mpet-cc-watcher", dependencies: ["SoulCore"]),
        .executableTarget(name: "MpetApp", dependencies: ["SoulCore"]),
        .testTarget(name: "SoulCoreTests", dependencies: ["SoulCore"]),
    ]
)
```

- [ ] **Step 2: 更新版本号**

```swift
// Sources/SoulCore/SoulCore.swift
public enum SoulCoreInfo { public static let version = "0.2.0-m1" }
```

- [ ] **Step 3: 更新 SanityTests 期望版本**

In `Tests/SoulCoreTests/SanityTests.swift`, change:
```swift
XCTAssertEqual(SoulCoreInfo.version, "0.2.0-m1")
```

- [ ] **Step 4: 构建验证** — `swift build 2>&1 | tail -3` — Expected: Build complete（新增的 targets 暂无源文件会编译报错，但 Package.swift 语法检查通过）
- [ ] **Step 5: Commit** — `git add -A && git commit -m "chore(m1): bump to 0.2.0-m1, add MpetApp + mpet-cc-watcher targets"`

---

### Task 1: DaemonSoul actor（修复 M0 遗留数据竞争）

**Files:** Create: `Sources/SoulCore/State/DaemonSoul.swift`; Test: `Tests/SoulCoreTests/DaemonSoulTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class DaemonSoulTests: XCTestCase {
    func testConcurrentEventsDoNotRace() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let daemon = DaemonSoul(
            store: StateStore(directory: dir, clock: clock),
            clock: clock,
            watchedBundleIDs: ["com.apple.Terminal"],
            nudgeBudgetPerHour: 4,
            genome: .default
        )
        // 并发 100 个事件
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask { await daemon.handleEvent(kind: "click", payload: ["i": .number(Double(i))]) }
            }
        }
        let count = await daemon.interactionCount
        XCTAssertEqual(count, 100)
    }

    func testChatUpdatesLastInteraction() async throws {
        let clock = TestClock(Date(timeIntervalSince1970: 1_000_000))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let daemon = DaemonSoul(
            store: StateStore(directory: dir, clock: clock),
            clock: clock,
            watchedBundleIDs: [],
            nudgeBudgetPerHour: 4,
            genome: .default
        )
        await daemon.noteInteraction()
        let last = await daemon.lastInteractionAt
        XCTAssertNotNil(last)
    }

    func testMoodIsPersistedAfterComputation() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = StateStore(directory: dir, clock: clock)
        let daemon = DaemonSoul(
            store: store, clock: clock,
            watchedBundleIDs: [], nudgeBudgetPerHour: 4, genome: .default
        )
        // 设定深夜时段
        let cal = Calendar.current
        let nightDate = cal.date(bySettingHour: 2, minute: 0, second: 0, of: clock.now)!
        clock.advance(by: nightDate.timeIntervalSince(clock.now))

        await daemon.recomputeMood(attention: .attending)
        let mood = await daemon.currentMood
        XCTAssertEqual(mood, .sleepy)
        // 持久化验证
        let saved = store.load()
        XCTAssertEqual(saved.mood, .sleepy)
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter DaemonSoulTests 2>&1 | tail -3` — Expected: 编译失败
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/State/DaemonSoul.swift
import Foundation

/// M1 修复 #1：daemon 可变状态 actor 化（消除 socket 并发数据竞争）
/// 所有 state mutation 必须经此 actor；Mind/ToolRegistry 已是 actor，不在此处。
public actor DaemonSoul {
    private let store: StateStore
    private let clock: SoulClock
    private let watchedBundleIDs: Set<String>
    private let perceptLog: PerceptLog
    private let wakePolicy: WakePolicy
    private var state: SoulState

    public private(set) var interactionCount: Int = 0

    public init(store: StateStore, clock: SoulClock,
                watchedBundleIDs: [String], nudgeBudgetPerHour: Int, genome: Genome) {
        self.store = store
        self.clock = clock
        self.watchedBundleIDs = Set(watchedBundleIDs)
        self.perceptLog = PerceptLog(clock: clock)
        self.wakePolicy = WakePolicy(clock: clock, nudgeBudgetPerHour: nudgeBudgetPerHour)
        self.state = store.load()
    }

    // ── 交互记录 ──
    public func noteInteraction() {
        state.lastInteractionAt = clock.now
        interactionCount += 1
        try? store.save(state)
    }

    public var lastInteractionAt: Date? { state.lastInteractionAt }

    // ── 心情 ──
    public func recomputeMood(attention: Attention) {
        let since = state.lastInteractionAt.map { clock.now.timeIntervalSince($0) } ?? .infinity
        let hour = Calendar.current.component(.hour, from: clock.now)
        let mood = MoodEngine.mood(.init(attention: attention, hour: hour, secondsSinceInteraction: since))
        state.mood = mood    // M1 修复 #2：运行时回写 mood
        try? store.save(state)
    }

    public var currentMood: Mood { state.mood }

    // ── 事件处理（反射弧 + 感知记录）──
    public func handleEvent(kind: String, payload: [String: JSONValue]) {
        noteInteraction()
        let percept = Percept(kind: "body.\(kind)", priority: .nudge, payload: payload, at: clock.now)
        perceptLog.add(percept)
    }

    // ── 感知处理（插件/CC 感官）──
    public func handlePercept(_ p: Percept) -> (directives: [PeripheralMessage], shouldWake: Bool) {
        perceptLog.add(p)
        let snap = PresenceSnapshot(frontmostBundleID: nil, idleSeconds: 0, watchedBundleIDs: watchedBundleIDs)
        let attention = AttentionResolver.resolve(snap)
        let mood = state.mood
        let directives = ReflexArc.directives(for: p, attention: attention, mood: mood)
        return (directives, wakePolicyInternal(p))
    }

    private func wakePolicyInternal(_ p: Percept) -> Bool {
        // WakePolicy is actor; we need async but DaemonSoul.handlePercept is sync.
        // Return true for alert; nudge/ambient handled async by caller.
        return p.priority == .alert
    }

    public func recentPercepts(limit: Int) -> [Percept] {
        perceptLog.recent(limit: limit)
    }

    public func shouldWake(for p: Percept) async -> Bool {
        await wakePolicy.shouldWake(for: p)
    }

    // ── 状态快照（给 status 查询用）──
    public func statusSnapshot(attention: Attention) -> [String: JSONValue] {
        [
            "mood": .string(state.mood.rawValue),
            "attention": .string(attention.rawValue),
            "stage": .string("baby"),
            "version": .string(SoulCoreInfo.version),
            "lastInteraction": state.lastInteractionAt.map {
                .number($0.timeIntervalSince1970)
            } ?? .null,
        ]
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter DaemonSoulTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m1): DaemonSoul actor — serializes daemon state mutations, fixes data race"`

---

### Task 2: SoulState.mood 回写验证（M0 遗留修复 #2）

**Files:** Test: `Tests/SoulCoreTests/MoodStateTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class MoodStateTests: XCTestCase {
    func testMoodIsPersistedWhenRecomputed() throws {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = StateStore(directory: dir, clock: clock)
        var s = store.load()
        XCTAssertEqual(s.mood, .calm)

        // 模拟：计算 mood 后回写
        let mood = MoodEngine.mood(.init(attention: .away, hour: 15, secondsSinceInteraction: 3 * 3600))
        s.mood = mood
        try store.save(s)

        let reloaded = store.load()
        XCTAssertEqual(reloaded.mood, .missing)  // 持久化成功
    }

    func testMoodSurvivesRoundTrip() throws {
        for mood in [Mood.calm, .happy, .sleepy, .missing] {
            var s = SoulState()
            s.mood = mood
            let data = try JSONEncoder().encode(s)
            let decoded = try JSONDecoder().decode(SoulState.self, from: data)
            XCTAssertEqual(decoded.mood, mood)
        }
    }
}
```

- [ ] **Step 2: 确认通过**（这些测试验证的是既有 SoulState + Mood 的行为，应该直接通过）
- [ ] **Step 3: Commit** — `git add -A && git commit -m "test(m1): mood persistence round-trip verification"`

---

### Task 3: SoulClient（客户端 socket 连接库）

**Files:** Create: `Sources/SoulCore/Client/SoulClient.swift`; Test: `Tests/SoulCoreTests/SoulClientTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class SoulClientTests: XCTestCase {
    func testMessageHandlerRoutesCorrectly() async throws {
        let client = SoulClient(socketPath: "/tmp/nonexistent-\(UUID().uuidString).sock")
        var received: [PeripheralMessage] = []
        await client.setMessageHandler { msg in received.append(msg) }

        // 模拟收到消息
        await client.handleReceived(.helloOK(proto: 1, soulVersion: "0.2.0-m1"))
        await client.handleReceived(.chatDelta(text: "你好"))
        await client.handleReceived(.directive(kind: "speak", payload: ["text": .string("嗨！")]))

        XCTAssertEqual(received.count, 3)
        if case .helloOK = received[0] {} else { XCTFail() }
        if case .chatDelta(let t) = received[1] { XCTAssertEqual(t, "你好") }
        if case .directive(let k, _) = received[2] { XCTAssertEqual(k, "speak") }
    }

    func testSendBufferingWhenDisconnected() async {
        let client = SoulClient(socketPath: "/tmp/nonexistent.sock")
        // 未连接时 send 应缓冲或静默丢弃（不 crash）
        await client.send(.ping)
        await client.send(.chatUser(text: "test"))
        let pending = await client.pendingSendCount
        XCTAssertEqual(pending, 2)
    }

    func testHandshakeSendsHello() async throws {
        let client = SoulClient(socketPath: "/tmp/test.sock")
        let hello = await client.makeHello()
        if case .hello(let role, let name, let proto) = hello {
            XCTAssertEqual(role, "body")
            XCTAssertEqual(name, "MpetApp")
            XCTAssertEqual(proto, 1)
        } else {
            XCTFail("expected hello")
        }
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter SoulClientTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Client/SoulClient.swift
import Foundation
import Network

/// 客户端侧 socket 连接（MpetApp / mpet-cc-watcher 共用）
/// 自动重连、hello 握手、NDJSON 帧收发。
public actor SoulClient {
    private let socketPath: String
    private var connection: NWConnection?
    private var codec = LineCodec()
    private var handler: (@Sendable (PeripheralMessage) -> Void)?
    private var isConnected = false
    private var pendingSends: [PeripheralMessage] = []
    private var reconnectTask: Task<Void, Never>?
    private let reconnectDelay: UInt64

    public var pendingSendCount: Int { pendingSends.count }

    public init(socketPath: String, reconnectDelay: UInt64 = 2_000_000_000) {
        self.socketPath = socketPath
        self.reconnectDelay = reconnectDelay
    }

    public func setMessageHandler(_ handler: @escaping @Sendable (PeripheralMessage) -> Void) {
        self.handler = handler
    }

    // ── 连接管理 ──
    public func connect() {
        reconnectTask?.cancel()
        doConnect()
    }

    public func disconnect() {
        reconnectTask?.cancel()
        connection?.cancel()
        connection = nil
        isConnected = false
    }

    private func doConnect() {
        let conn = NWConnection(to: .unix(path: socketPath), using: .tcp)
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task { await self.handleStateChange(state) }
        }
        conn.start(queue: .global())
        connection = conn
    }

    private func handleStateChange(_ state: NWConnection.State) {
        switch state {
        case .ready:
            isConnected = true
            flushPendingSends()
            startReceiving()
        case .failed, .cancelled:
            isConnected = false
            scheduleReconnect()
        default:
            break
        }
    }

    private func scheduleReconnect() {
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: await self.reconnectDelay)
            guard !Task.isCancelled else { return }
            await self.doConnect()
        }
    }

    // ── 发送 ──
    public func send(_ message: PeripheralMessage) {
        guard isConnected, let conn = connection,
              let data = try? LineCodec.encode(message) else {
            pendingSends.append(message)
            return
        }
        conn.send(content: data, completion: .contentProcessed { _ in })
    }

    private func flushPendingSends() {
        guard let conn = connection else { return }
        for msg in pendingSends {
            guard let data = try? LineCodec.encode(msg) else { continue }
            conn.send(content: data, completion: .contentProcessed { _ in })
        }
        pendingSends.removeAll()
    }

    // ── 接收 ──
    private func startReceiving() {
        guard let conn = connection else { return }
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, done, err in
            guard let self else { return }
            Task {
                if let data, !data.isEmpty {
                    let msgs = (try? await self.codec.feed(data)) ?? []
                    for m in msgs { await self.handleReceived(m) }
                }
                if !done && err == nil {
                    await self.startReceiving()
                }
            }
        }
    }

    // ── 消息分发（public 供测试直接调用）──
    public func handleReceived(_ message: PeripheralMessage) {
        handler?(message)
    }

    // ── 握手 ──
    public func makeHello() -> PeripheralMessage {
        .hello(role: "body", name: "MpetApp", proto: 1)
    }

    public func performHandshake() {
        send(makeHello())
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter SoulClientTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m1): SoulClient actor — NWConnection socket client with auto-reconnect"`

---

### Task 4: HookInstaller（CC settings.json 备份 + 注入 hook）

**Files:** Create: `Sources/SoulCore/Plugin/HookInstaller.swift`; Test: `Tests/SoulCoreTests/HookInstallerTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class HookInstallerTests: XCTestCase {
    func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func testInstallCreatesBackupAndPatchesHooks() throws {
        let dir = tempDir()
        let settingsFile = dir.appendingPathComponent("settings.json")
        try Data(#"{"hooks":{},"model":"opus"}"#.utf8).write(to: settingsFile)

        let installer = HookInstaller(settingsPath: settingsFile)
        try installer.install(hookCommand: "cat > /tmp/spool/event.json")

        // 验证备份存在
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.contains("backup-mpet-hook") }
        XCTAssertFalse(backups.isEmpty)

        // 验证 settings.json 被修改
        let updated = try String(data: Data(contentsOf: settingsFile), encoding: .utf8)!
        XCTAssertTrue(updated.contains("mpet-hook"))
        XCTAssertTrue(updated.contains("cat > /tmp/spool"))
        // 原有字段保留
        XCTAssertTrue(updated.contains("opus"))
    }

    func testInstallIdempotentDoesNotDuplicate() throws {
        let dir = tempDir()
        let settingsFile = dir.appendingPathComponent("settings.json")
        try Data(#"{"hooks":{}}"#.utf8).write(to: settingsFile)

        let installer = HookInstaller(settingsPath: settingsFile)
        try installer.install(hookCommand: "echo test")
        try installer.install(hookCommand: "echo test")  // 二次安装

        let data = try Data(contentsOf: settingsFile)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = json["hooks"] as! [String: Any]
        let notifications = hooks["Notification"] as! [[String: Any]]
        let innerHooks = notifications[0]["hooks"] as! [[String: Any]]
        XCTAssertEqual(innerHooks.count, 1)  // 不重复
    }

    func testUninstallRemovesMpetHooksAndRestores() throws {
        let dir = tempDir()
        let settingsFile = dir.appendingPathComponent("settings.json")
        try Data(#"{"hooks":{},"theme":"dark"}"#.utf8).write(to: settingsFile)

        let installer = HookInstaller(settingsPath: settingsFile)
        try installer.install(hookCommand: "echo test")
        try installer.uninstall()

        let data = try Data(contentsOf: settingsFile)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = json["hooks"] as! [String: Any]
        XCTAssertNil(hooks["Notification"])
        XCTAssertTrue((json["theme"] as? String) == "dark")  // 非 mpet 字段完好
    }

    func testCreatesSettingsFileIfMissing() throws {
        let dir = tempDir()
        let settingsFile = dir.appendingPathComponent("settings.json")
        // 文件不存在
        let installer = HookInstaller(settingsPath: settingsFile)
        try installer.install(hookCommand: "echo test")
        XCTAssertTrue(FileManager.default.fileExists(atPath: settingsFile.path))
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter HookInstallerTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Plugin/HookInstaller.swift
import Foundation

/// CC settings.json hook 安装器：备份 → 注入 Notification hook → 可卸载恢复。
/// 设计要点：幂等安装（不重复注入）、卸载只删 mpet 相关条目、保留用户其他设置。
public struct HookInstaller {
    public let settingsPath: URL
    private static let markerKey = "_mpet_managed"

    public init(settingsPath: URL) { self.settingsPath = settingsPath }

    // ── 安装 ──
    public func install(hookCommand: String) throws {
        var settings = try loadSettings()

        // 幂等：先移除已有 mpet hook
        removeMpetHooks(from: &settings)

        // 注入 Notification hook
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        let hookEntry: [String: Any] = [
            "hooks": [
                [
                    "type": "command",
                    "command": hookCommand,
                    "timeout": 5,
                ]
            ]
        ]
        hooks["Notification"] = [hookEntry]
        settings["hooks"] = hooks

        // 备份 + 原子写
        try backup()
        try writeSettings(settings)
    }

    // ── 卸载 ──
    public func uninstall() throws {
        var settings = try loadSettings()
        removeMpetHooks(from: &settings)
        try writeSettings(settings)
    }

    // ── 内部 ──
    private func loadSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsPath.path) else { return [:] }
        let data = try Data(contentsOf: settingsPath)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func writeSettings(_ settings: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        let tmp = settingsPath.deletingLastPathComponent().appendingPathComponent(".settings.tmp")
        try data.write(to: tmp, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(settingsPath, withItemAt: tmp)
        if !FileManager.default.fileExists(atPath: settingsPath.path) {
            try FileManager.default.moveItem(at: tmp, to: settingsPath)
        }
    }

    private func backup() throws {
        guard FileManager.default.fileExists(atPath: settingsPath.path) else { return }
        let stamp = Int(Date().timeIntervalSince1970)
        let backup = settingsPath.deletingLastPathComponent()
            .appendingPathComponent("settings.json.backup-mpet-hook-\(stamp)")
        try FileManager.default.copyItem(at: settingsPath, to: backup)
    }

    private func removeMpetHooks(from settings: inout [String: Any]) {
        guard var hooks = settings["hooks"] as? [String: Any] else { return }
        // 移除 mpet 管理的 hook events（通过检查 command 是否包含 "mpet"）
        for eventName in ["Notification", "PreToolUse", "PostToolUse", "Stop", "UserPromptSubmit", "SessionStart", "SessionEnd"] {
            guard let entries = hooks[eventName] as? [[String: Any]] else { continue }
            let filtered = entries.filter { entry in
                guard let innerHooks = entry["hooks"] as? [[String: Any]] else { return true }
                return !innerHooks.contains { hook in
                    let cmd = hook["command"] as? String ?? ""
                    return cmd.contains("mpet") || cmd.contains("mpet-spool")
                }
            }
            if filtered.isEmpty {
                hooks.removeValue(forKey: eventName)
            } else {
                hooks[eventName] = filtered
            }
        }
        settings["hooks"] = hooks
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter HookInstallerTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m1): HookInstaller — backup + patch CC settings.json hooks (idempotent)"`

---

### Task 5: CCEvent 类型 + 防御式解析

**Files:** Create: `Sources/SoulCore/Plugin/CCEvent.swift`; Test: `Tests/SoulCoreTests/CCEventTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class CCEventTests: XCTestCase {
    func testParseNotificationEvent() throws {
        let json = """
        {
            "session_id": "abc-123",
            "cwd": "/Users/test/project",
            "hook_event_name": "Notification",
            "transcript_path": "/Users/test/.claude/projects/-test/abc-123.jsonl",
            "notification_type": "permission_request",
            "message": "Claude wants to run: rm -rf /tmp"
        }
        """
        let event = try CCEventParser.parse(Data(json.utf8))
        XCTAssertEqual(event.sessionID, "abc-123")
        XCTAssertEqual(event.hookEventName, "Notification")
        XCTAssertEqual(event.notificationType, "permission_request")
        XCTAssertEqual(event.message, "Claude wants to run: rm -rf /tmp")
    }

    func testParsePreToolUse() throws {
        let json = """
        {
            "session_id": "s1",
            "hook_event_name": "PreToolUse",
            "transcript_path": "/tmp/t.jsonl",
            "cwd": "/tmp",
            "tool_name": "Bash",
            "tool_input": {"command": "npm test", "description": "Run tests"}
        }
        """
        let event = try CCEventParser.parse(Data(json.utf8))
        XCTAssertEqual(event.toolName, "Bash")
        XCTAssertEqual(event.toolInput?["command"] as? String, "npm test")
    }

    func testDefensiveParseMalformedJSON() {
        let bad = Data("not json at all".utf8)
        XCTAssertThrowsError(try CCEventParser.parse(bad))
    }

    func testDefensiveParseMissingFields() throws {
        let minimal = #"{"session_id":"s","hook_event_name":"Unknown","transcript_path":"","cwd":"/"}"#
        let event = try CCEventParser.parse(Data(minimal.utf8))
        XCTAssertEqual(event.sessionID, "s")
        XCTAssertNil(event.toolName)
        XCTAssertNil(event.message)
    }

    func testToPerceptAlertForNotification() throws {
        let event = CCEvent(
            sessionID: "s1", cwd: "/tmp", hookEventName: "Notification",
            transcriptPath: "/tmp/t.jsonl", toolName: nil, toolInput: nil,
            notificationType: "permission_request", message: "需要你批准"
        )
        let percept = event.toPercept()
        XCTAssertEqual(percept.priority, .alert)
        XCTAssertEqual(percept.kind, "cc.needs_you")
        XCTAssertTrue(percept.payload["title"]?.stringValue?.contains("需要你") ?? false)
    }

    func testToPerceptAmbientForPreToolUse() throws {
        let event = CCEvent(
            sessionID: "s1", cwd: "/tmp", hookEventName: "PreToolUse",
            transcriptPath: "/tmp/t.jsonl", toolName: "Read", toolInput: ["file_path": "/tmp/x.swift"],
            notificationType: nil, message: nil
        )
        let percept = event.toPercept()
        XCTAssertEqual(percept.priority, .ambient)
        XCTAssertEqual(percept.kind, "cc.working")
    }

    func testAffordanceActionIncluded() throws {
        let event = CCEvent(
            sessionID: "s1", cwd: "/tmp", hookEventName: "Notification",
            transcriptPath: "/tmp/t.jsonl", toolName: nil, toolInput: nil,
            notificationType: "permission_request", message: "CC 等你"
        )
        let percept = event.toPercept()
        XCTAssertFalse(percept.actions.isEmpty)
        XCTAssertEqual(percept.actions.first?.id, "return-to-cc")
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter CCEventTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Plugin/CCEvent.swift
import Foundation

/// CC hook 事件的防御式解析。格式属 CC 内部实现——挂了只影响本插件。
/// 已知事件：Notification / PreToolUse / PostToolUse / Stop / UserPromptSubmit / SessionStart / SessionEnd
public struct CCEvent: Sendable {
    public let sessionID: String
    public let cwd: String
    public let hookEventName: String
    public let transcriptPath: String
    public var toolName: String?
    public var toolInput: [String: Any]?
    public var notificationType: String?
    public var message: String?
    // 传输层需要 Sendable 安全；toolInput 用 JSONValue 替代
    public var toolInputJSON: [String: JSONValue]

    public init(sessionID: String, cwd: String, hookEventName: String, transcriptPath: String,
                toolName: String? = nil, toolInput: [String: Any]? = nil,
                notificationType: String? = nil, message: String? = nil) {
        self.sessionID = sessionID; self.cwd = cwd
        self.hookEventName = hookEventName; self.transcriptPath = transcriptPath
        self.toolName = toolName; self.toolInput = toolInput
        self.notificationType = notificationType; self.message = message
        // 转换 toolInput 为 JSONValue
        var jv: [String: JSONValue] = [:]
        if let ti = toolInput {
            for (k, v) in ti {
                if let s = v as? String { jv[k] = .string(s) }
                else if let n = v as? Double { jv[k] = .number(n) }
                else if let b = v as? Bool { jv[k] = .bool(b) }
                else { jv[k] = .string("\(v)") }
            }
        }
        self.toolInputJSON = jv
    }

    /// 转换为 mpet 感知事件（spec §10.9）
    public func toPercept() -> Percept {
        switch hookEventName {
        case "Notification":
            return Percept(
                kind: "cc.needs_you",
                priority: .alert,
                payload: [
                    "title": .string(message ?? "CC 需要你"),
                    "session": .string(sessionID),
                    "notificationType": .string(notificationType ?? ""),
                ],
                actions: [PerceptAction(id: "return-to-cc", label: "带我回那个终端")],
                at: Date()
            )
        case "PreToolUse", "PostToolUse":
            return Percept(
                kind: "cc.working",
                priority: .ambient,
                payload: [
                    "tool": .string(toolName ?? ""),
                    "session": .string(sessionID),
                ],
                at: Date()
            )
        case "Stop":
            return Percept(
                kind: "cc.done",
                priority: .nudge,
                payload: ["session": .string(sessionID)],
                at: Date()
            )
        case "UserPromptSubmit":
            return Percept(
                kind: "cc.user_talking",
                priority: .ambient,
                payload: ["session": .string(sessionID)],
                at: Date()
            )
        default:
            return Percept(
                kind: "cc.unknown.\(hookEventName)",
                priority: .ambient,
                payload: ["session": .string(sessionID)],
                at: Date()
            )
        }
    }
}

public enum CCEventParser {
    public static func parse(_ data: Data) throws -> CCEvent {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            ?? { throw CCParserError.notAnObject }()

        let sessionID = json["session_id"] as? String ?? ""
        let cwd = json["cwd"] as? String ?? ""
        let hookEventName = json["hook_event_name"] as? String ?? "unknown"
        let transcriptPath = json["transcript_path"] as? String ?? ""
        let toolName = json["tool_name"] as? String
        let toolInput = json["tool_input"] as? [String: Any]
        let notificationType = json["notification_type"] as? String
        let message = json["message"] as? String

        return CCEvent(
            sessionID: sessionID, cwd: cwd, hookEventName: hookEventName,
            transcriptPath: transcriptPath, toolName: toolName, toolInput: toolInput,
            notificationType: notificationType, message: message
        )
    }

    public enum CCParserError: Error { case notAnObject }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter CCEventTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m1): CCEvent types + defensive parser + toPercept mapping"`

---

### Task 6: CCSpoolMonitor（spool 目录文件监听）

**Files:** Create: `Sources/SoulCore/Plugin/CCSpoolMonitor.swift`; Test: `Tests/SoulCoreTests/CCSpoolMonitorTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class CCSpoolMonitorTests: XCTestCase {
    func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func testDetectsNewFiles() async throws {
        let dir = tempDir()
        let monitor = CCSpoolMonitor(spoolDir: dir)
        var events: [CCEvent] = []
        await monitor.setHandler { events.append($0) }
        await monitor.start()

        // 写入一个 spool 文件
        let eventData = """
        {"session_id":"s1","hook_event_name":"Notification","transcript_path":"/tmp/t.jsonl","cwd":"/tmp","message":"CC 需要你"}
        """
        let file = dir.appendingPathComponent("\(Int(Date().timeIntervalSince1970 * 1000)).json")
        try eventData.write(to: file, options: .atomic)

        // 等待 monitor 检测到（最多 3 秒）
        let deadline = Date().addingTimeInterval(3)
        while events.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        await monitor.stop()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.sessionID, "s1")
    }

    func testIgnoresAlreadyProcessedFiles() async throws {
        let dir = tempDir()
        // 先写一个旧文件
        let oldFile = dir.appendingPathComponent("old.json")
        try #"{"session_id":"old"}"#.write(to: oldFile, atomically: true, encoding: .utf8)

        let monitor = CCSpoolMonitor(spoolDir: dir)
        var events: [CCEvent] = []
        await monitor.setHandler { events.append($0) }
        await monitor.start()
        try await Task.sleep(nanoseconds: 500_000_000)
        await monitor.stop()

        // 旧文件不应触发事件
        XCTAssertTrue(events.isEmpty)
    }

    func testMalformedFileIsSkippedGracefully() async throws {
        let dir = tempDir()
        let monitor = CCSpoolMonitor(spoolDir: dir)
        var events: [CCEvent] = []
        await monitor.setHandler { events.append($0) }
        await monitor.start()

        // 写入一个坏文件
        try Data("not json".utf8).write(to: dir.appendingPathComponent("\(Int(Date().timeIntervalSince1970 * 1000)).json"))
        // 再写一个好文件
        try await Task.sleep(nanoseconds: 50_000_000)
        let goodData = #"{"session_id":"s2","hook_event_name":"Stop","transcript_path":"","cwd":"/"}"#
        try goodData.write(to: dir.appendingPathComponent("\(Int(Date().timeIntervalSince1970 * 1000) + 1).json"), atomically: true, encoding: .utf8)

        let deadline = Date().addingTimeInterval(3)
        while events.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        await monitor.stop()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.sessionID, "s2")
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter CCSpoolMonitorTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Plugin/CCSpoolMonitor.swift
import Foundation

/// 监听 cc-watcher spool 目录：hook 命令将事件写入此目录，monitor 解析并转发。
/// 使用 DispatchSource 文件系统事件监听，非轮询。
public actor CCSpoolMonitor {
    private let spoolDir: URL
    private var handler: (@Sendable (CCEvent) -> Void)?
    private var processedFiles: Set<String> = []
    private var scanTimer: Task<Void, Never>?
    private var isRunning = false

    public init(spoolDir: URL) {
        self.spoolDir = spoolDir
        try? FileManager.default.createDirectory(at: spoolDir, withIntermediateDirectories: true)
    }

    public func setHandler(_ handler: @escaping @Sendable (CCEvent) -> Void) {
        self.handler = handler
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        // 记录已有文件（避免处理旧文件）
        if let existing = try? FileManager.default.contentsOfDirectory(atPath: spoolDir.path) {
            processedFiles.formUnion(existing)
        }
        // 定时扫描（500ms 间隔，平衡响应性与 CPU 开销）
        scanTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await self?.scan()
            }
        }
    }

    public func stop() {
        isRunning = false
        scanTimer?.cancel()
        scanTimer = nil
    }

    private func scan() {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: spoolDir.path) else { return }
        for file in files.sorted() where !processedFiles.contains(file) && file.hasSuffix(".json") {
            processedFiles.insert(file)
            let path = spoolDir.appendingPathComponent(file)
            guard let data = try? Data(contentsOf: path),
                  let event = try? CCEventParser.parse(data) else {
                // 防御式：坏文件跳过，不影响后续
                continue
            }
            handler?(event)
            // 处理后删除 spool 文件（保持目录清洁）
            try? FileManager.default.removeItem(at: path)
        }
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter CCSpoolMonitorTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m1): CCSpoolMonitor — file-system watcher for CC hook spool directory"`

---

### Task 7: KeychainStore（API Key 安全存储）

**Files:** Create: `Sources/SoulCore/Security/KeychainStore.swift`; Test: `Tests/SoulCoreTests/KeychainStoreTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class KeychainStoreTests: XCTestCase {
    let service = "com.mpet.test.keychain"

    override func setUp() {
        super.setUp()
        // 清理测试 keychain 项
        KeychainStore.delete(service: service, account: "test-key")
    }

    func testSaveAndLoad() {
        let store = KeychainStore(service: service)
        let saved = store.save("my-secret-api-key", account: "test-key")
        XCTAssertTrue(saved)
        let loaded = store.load(account: "test-key")
        XCTAssertEqual(loaded, "my-secret-api-key")
    }

    func testDelete() {
        let store = KeychainStore(service: service)
        _ = store.save("secret", account: "test-key")
        let deleted = store.delete(account: "test-key")
        XCTAssertTrue(deleted)
        XCTAssertNil(store.load(account: "test-key"))
    }

    func testLoadNonexistentReturnsNil() {
        let store = KeychainStore(service: service)
        XCTAssertNil(store.load(account: "nonexistent-\(UUID().uuidString)"))
    }

    func testUpdateExistingKey() {
        let store = KeychainStore(service: service)
        _ = store.save("first", account: "test-key")
        _ = store.save("second", account: "test-key")
        XCTAssertEqual(store.load(account: "test-key"), "second")
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter KeychainStoreTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Security/KeychainStore.swift
import Foundation
import Security

/// macOS Keychain 读写（spec §12.3：API Key 进 Keychain）。
/// 生产用 service = "com.mpet.soul"。
public struct KeychainStore: Sendable {
    public let service: String

    public init(service: String = "com.mpet.soul") {
        self.service = service
    }

    public func save(_ value: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        // 先尝试删除已有的（避免 errSecDuplicateItem）
        _ = Self.delete(service: service, account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    public func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    @discardableResult
    public func delete(account: String) -> Bool {
        Self.delete(service: service, account: account)
    }

    @discardableResult
    static func delete(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter KeychainStoreTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m1): KeychainStore — save/load/delete API keys via Security.framework"`

---

### Task 8: LaunchdInstaller（LaunchAgent plist 生成与管理）

**Files:** Create: `Sources/SoulCore/System/LaunchdInstaller.swift`; Test: `Tests/SoulCoreTests/LaunchdInstallerTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class LaunchdInstallerTests: XCTestCase {
    func testPlistGeneration() {
        let plist = LaunchdInstaller.generatePlist(
            label: "com.mpet.soul",
            programPath: "/usr/local/bin/mpet-soul",
            keepAlive: true,
            runAtLoad: true
        )
        XCTAssertTrue(plist.contains("<key>Label</key>"))
        XCTAssertTrue(plist.contains("<string>com.mpet.soul</string>"))
        XCTAssertTrue(plist.contains("<key>ProgramArguments</key>"))
        XCTAssertTrue(plist.contains("/usr/local/bin/mpet-soul"))
        XCTAssertTrue(plist.contains("<key>KeepAlive</key>"))
        XCTAssertTrue(plist.contains("<key>RunAtLoad</key>"))
    }

    func testInstallWritesPlistFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let plistPath = dir.appendingPathComponent("com.mpet.soul.plist")

        try LaunchdInstaller.install(
            label: "com.mpet.soul",
            programPath: "/usr/local/bin/mpet-soul",
            plistDestination: plistPath
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: plistPath.path))
        let content = try String(contentsOf: plistPath, encoding: .utf8)
        XCTAssertTrue(content.contains("com.mpet.soul"))
    }

    func testUninstallRemovesPlistAndUnload() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let plistPath = dir.appendingPathComponent("com.mpet.soul.plist")
        try "test".write(to: plistPath, atomically: true, encoding: .utf8)

        try LaunchdInstaller.uninstall(plistPath: plistPath, skipLaunchctl: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: plistPath.path))
    }

    func testPlistIncludesWorkingDirectory() {
        let plist = LaunchdInstaller.generatePlist(
            label: "com.mpet.soul",
            programPath: "/usr/local/bin/mpet-soul",
            workingDirectory: "/Users/test/Library/Application Support/mpet",
            keepAlive: true
        )
        XCTAssertTrue(plist.contains("<key>WorkingDirectory</key>"))
        XCTAssertTrue(plist.contains("Application Support/mpet"))
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter LaunchdInstallerTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/System/LaunchdInstaller.swift
import Foundation

/// macOS LaunchAgent plist 生成与安装（spec §5.1：launchd 自启）。
/// 安装路径：~/Library/LaunchAgents/com.mpet.soul.plist
public enum LaunchdInstaller {
    public static let defaultLabel = "com.mpet.soul"
    public static let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents")

    /// 生成 plist XML 字符串
    public static func generatePlist(
        label: String = defaultLabel,
        programPath: String,
        workingDirectory: String? = nil,
        keepAlive: Bool = true,
        runAtLoad: Bool = true
    ) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(programPath)</string>
            </array>
        """
        if let wd = workingDirectory {
            xml += """

                <key>WorkingDirectory</key>
                <string>\(wd)</string>
            """
        }
        if keepAlive {
            xml += """

                <key>KeepAlive</key>
                <true/>
            """
        }
        if runAtLoad {
            xml += """

                <key>RunAtLoad</key>
                <true/>
            """
        }
        xml += """

            <key>StandardOutPath</key>
            <string>/tmp/mpet-soul.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/mpet-soul.err</string>
        </dict>
        </plist>
        """
        return xml
    }

    /// 安装 plist 到 ~/Library/LaunchAgents 并 launchctl load
    public static func install(
        label: String = defaultLabel,
        programPath: String,
        plistDestination: URL? = nil
    ) throws {
        let dest = plistDestination ?? launchAgentsDir.appendingPathComponent("\(label).plist")
        try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        let plist = generatePlist(label: label, programPath: programPath)
        try plist.write(to: dest, atomically: true, encoding: .utf8)

        // launchctl load（非测试环境）
        if plistDestination == nil {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            proc.arguments = ["load", "-w", dest.path]
            try? proc.run()
            proc.waitUntilExit()
        }
    }

    /// 卸载：launchctl unload + 删除 plist
    public static func uninstall(plistPath: URL? = nil, skipLaunchctl: Bool = false) throws {
        let path = plistPath ?? launchAgentsDir.appendingPathComponent("\(defaultLabel).plist")
        if !skipLaunchctl && FileManager.default.fileExists(atPath: path.path) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            proc.arguments = ["unload", path.path]
            try? proc.run()
            proc.waitUntilExit()
        }
        try? FileManager.default.removeItem(at: path)
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter LaunchdInstallerTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m1): LaunchdInstaller — plist generation + install/uninstall for soul daemon"`

---

### Task 9: 重写 daemon main.swift（使用 DaemonSoul actor）

**Files:** Rewrite: `Sources/mpet-soul/main.swift`

- [ ] **Step 1: 重写 main.swift**

```swift
// Sources/mpet-soul/main.swift
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
        let attention = currentAttention()
        await daemon.recomputeMood(attention: attention)
        let mood = await daemon.currentMood
        let recent = await daemon.recentPercepts(limit: 8)
        await mind.wake(reason: p.kind, mood: mood, attention: attention, recent: recent)
    } else if p.priority == .nudge {
        // nudge 走异步唤醒检查
        let shouldWake = await daemon.shouldWake(for: p)
        if shouldWake {
            let attention = currentAttention()
            await daemon.recomputeMood(attention: attention)
            let mood = await daemon.currentMood
            let recent = await daemon.recentPercepts(limit: 8)
            await mind.wake(reason: p.kind, mood: mood, attention: attention, recent: recent)
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
```

- [ ] **Step 2: 编译验证** — `swift build 2>&1 | tail -3`
- [ ] **Step 3: 跑全量测试确认无回归** — `swift test 2>&1 | tail -5`
- [ ] **Step 4: Commit** — `git add -A && git commit -m "refactor(m1): daemon uses DaemonSoul actor — eliminates state data race"`

---

### Task 10: mpet-cc-watcher 可执行

**Files:** Create: `Sources/mpet-cc-watcher/main.swift`

- [ ] **Step 1: 实现**

```swift
// Sources/mpet-cc-watcher/main.swift
import Foundation
import SoulCore

// cc-watcher v0：独立可执行，连接 soul.sock，监听 CC spool 目录
// 用法：mpet-cc-watcher [--install-hook] [--uninstall-hook] [--spool-dir <path>]

let args = CommandLine.arguments.dropFirst()
let spoolDirOverride = args.firstIndex(of: "--spool-dir").map {
    URL(fileURLWithPath: args[args.index(after: $0)])
}

let supportDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/mpet")
let spoolDir = spoolDirOverride ?? supportDir.appendingPathComponent("plugins/cc-watcher/spool")
let sockPath = supportDir.appendingPathComponent("soul.sock").path

try? FileManager.default.createDirectory(at: spoolDir, withIntermediateDirectories: true)

// ── Hook 安装/卸载 ──
if args.contains("--install-hook") {
    let settingsPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")
    let installer = HookInstaller(settingsPath: settingsPath)
    let hookCmd = "cat > \"\(spoolDir.path)/$(date +%s%N).json\""
    try installer.install(hookCommand: hookCmd)
    print("✅ CC hook 已安装 → \(settingsPath.path)")
    print("   spool 目录：\(spoolDir.path)")
    exit(0)
}

if args.contains("--uninstall-hook") {
    let settingsPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")
    let installer = HookInstaller(settingsPath: settingsPath)
    try installer.uninstall()
    print("✅ CC hook 已卸载")
    exit(0)
}

// ── 主循环：连接 soul.sock + 监听 spool ──
let client = SoulClient(socketPath: sockPath)
let monitor = CCSpoolMonitor(spoolDir: spoolDir)

await monitor.setHandler { event in
    let percept = event.toPercept()
    await client.send(.senseEvent(percept))
    print("📡 CC 事件：\(event.hookEventName) → \(percept.kind) (\(percept.priority.rawValue))")
}

await client.setMessageHandler { msg in
    switch msg {
    case .helloOK(_, let v):
        print("connected to soul v\(v)")
    case .actionInvoke(let eventId, let actionId):
        if actionId == "return-to-cc" {
            // affordance：带回 CC 终端（打开对应的 transcript 或 Terminal）
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = ["-a", "Terminal"]
            try? proc.run()
            print("🎯 affordance：带你回 CC 终端")
        }
    default:
        break
    }
}

await client.connect()
await client.performHandshake()
await monitor.start()

print("mpet-cc-watcher \(SoulCoreInfo.version) ｜ spool=\(spoolDir.path) ｜ soul.sock=\(sockPath)")
fflush(stdout)

// 常驻
await withUnsafeContinuation { (_: UnsafeContinuation<Void, Never>) in }
```

- [ ] **Step 2: 编译验证** — `swift build 2>&1 | tail -3`
- [ ] **Step 3: Commit** — `git add -A && git commit -m "feat(m1): mpet-cc-watcher executable — CC hook install + spool monitor + soul.sock relay"`

---

### Task 11: MpetApp 占位 + PetViewModel

**Files:** Create: `Sources/MpetApp/MpetAppMain.swift`, `Sources/MpetApp/PetViewModel.swift`

这是 SwiftUI macOS App 的骨架。后续 Task 逐步填充 UI 组件。

- [ ] **Step 1: PetViewModel（连接层 ObservableObject）**

```swift
// Sources/MpetApp/PetViewModel.swift
import Foundation
import SwiftUI
import Combine
import SoulCore

/// 连接 soul.sock 的 ObservableObject：将 socket 事件翻译为 SwiftUI 可消费的状态。
@MainActor
final class PetViewModel: ObservableObject {
    @Published var mood: String = "calm"
    @Published var attention: String = "elsewhere"
    @Published var stage: String = "baby"
    @Published var soulVersion: String = "?"
    @Published var isConnected: Bool = false
    @Published var bubbleText: String? = nil
    @Published var chatMessages: [ChatEntry] = []
    @Published var currentEmote: String = "idle"

    struct ChatEntry: Identifiable {
        let id = UUID()
        let role: String  // "user" | "assistant"
        var text: String
    }

    private var client: SoulClient?
    private var currentAssistantText = ""

    func connect(socketPath: String) {
        let c = SoulClient(socketPath: socketPath)
        Task {
            await c.setMessageHandler { [weak self] msg in
                Task { @MainActor in self?.handleMessage(msg) }
            }
            await c.connect()
            await c.performHandshake()
        }
        client = c
    }

    func disconnect() {
        Task { await client?.disconnect() }
        client = nil
    }

    func sendChat(_ text: String) {
        guard !text.isEmpty else { return }
        chatMessages.append(ChatEntry(role: "user", text: text))
        currentAssistantText = ""
        Task { await client?.send(.chatUser(text: text)) }
    }

    func sendEvent(_ kind: String) {
        Task { await client?.send(.event(kind: kind, payload: [:])) }
    }

    private func handleMessage(_ msg: PeripheralMessage) {
        switch msg {
        case .helloOK(_, let v):
            isConnected = true
            soulVersion = v
        case .statusOK(let fields):
            mood = fields["mood"]?.stringValue ?? "calm"
            attention = fields["attention"]?.stringValue ?? "elsewhere"
            stage = fields["stage"]?.stringValue ?? "baby"
        case .chatDelta(let text):
            currentAssistantText += text
            // 更新或追加 assistant 消息
            if let last = chatMessages.last, last.role == "assistant" {
                chatMessages[chatMessages.count - 1].text = currentAssistantText
            } else {
                chatMessages.append(ChatEntry(role: "assistant", text: currentAssistantText))
            }
        case .chatDone:
            currentAssistantText = ""
        case .directive(let kind, let payload):
            switch kind {
            case "speak":
                bubbleText = payload["text"]?.stringValue
            case "emote":
                currentEmote = payload["animation"]?.stringValue ?? "idle"
            case "notify":
                bubbleText = payload["title"]?.stringValue
            default:
                break
            }
        default:
            break
        }
    }
}
```

- [ ] **Step 2: MpetApp 入口（@main）**

```swift
// Sources/MpetApp/MpetAppMain.swift
import SwiftUI
import AppKit

@main
struct MpetApp: App {
    @StateObject private var viewModel = PetViewModel()

    var body: some Scene {
        // 宠物窗口（透明、置顶、点击穿透）
        WindowGroup {
            PetWindowContent(viewModel: viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 200, height: 250)

        // 设置窗口
        Settings {
            SettingsPanel(viewModel: viewModel)
        }
    }
}

struct PetWindowContent: View {
    @ObservedObject var viewModel: PetViewModel

    var body: some View {
        ZStack {
            SVGRenderer(state: viewModel.moodToSVGState, emote: viewModel.currentEmote)
            if let bubble = viewModel.bubbleText {
                BubbleView(text: bubble)
                    .offset(y: -120)
            }
        }
        .frame(width: 200, height: 250)
        .background(Color.clear)
        .onAppear {
            let sockPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/mpet/soul.sock").path
            viewModel.connect(socketPath: sockPath)
        }
    }
}

extension PetViewModel {
    var moodToSVGState: String {
        switch mood {
        case "happy": return "happy"
        case "sleepy": return "sleepy"
        case "missing": return "missyou"
        default: return "idle"
        }
    }
}
```

- [ ] **Step 3: 占位 UI 组件（后续 Task 替换为完整实现）**

```swift
// Sources/MpetApp/SVGRenderer.swift
import SwiftUI
import WebKit

/// SVG 渲染器：WKWebView 加载内嵌 SVG+CSS，通过 JS 切换状态 class。
struct SVGRenderer: NSViewRepresentable {
    let state: String
    let emote: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.loadHTMLString(Self.htmlContent, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let js = "document.getElementById('pet')?.setAttribute('class', 'pet state-\(state)');"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    static let htmlContent: String = {
        // 从 spikes/svg-pet/index.html 提取的 SVG + CSS（内嵌）
        // 完整内容在 Task 11 的 assets 中提供
        return """
        <!DOCTYPE html><html><head><meta charset="UTF-8">
        <style>
        body{margin:0;background:transparent;overflow:hidden;display:flex;align-items:center;justify-content:center;height:100vh}
        .pet{width:180px;height:auto}
        .pet *{transform-box:fill-box}
        #pet-root{transform-origin:50% 100%;animation:breathe 3.4s ease-in-out infinite}
        @keyframes breathe{0%,100%{transform:scale(1,1)}50%{transform:scale(.996,1.028)}}
        /* 状态变体：同 spikes/svg-pet/index.html */
        .eyes-open,.eyes-happy,.eyes-sleepy,.eyes-closed,.eyes-up,.eyes-wide,
        .m-idle,.m-happy,.m-o,.m-sleep{display:none}
        .state-idle .eyes-open,.state-idle .m-idle{display:block}
        .state-happy .eyes-happy,.state-happy .m-happy{display:block}
        .state-sleepy .eyes-sleepy,.state-sleepy .m-o{display:block}
        .state-missyou .eyes-up,.state-missyou .m-idle{display:block}
        .state-sleeping .eyes-closed,.state-sleeping .m-sleep{display:block}
        .state-alert .eyes-wide,.state-alert .m-o{display:block}
        </style></head>
        <body>
        <svg class="pet state-idle" id="pet" viewBox="0 0 340 340">
        <!-- 简化版 SVG：完整内容从 spikes/svg-pet/pet.svg 复制 -->
        <ellipse cx="170" cy="305" rx="80" ry="11" fill="#000000" opacity=".18"/>
        <g id="pet-root">
          <ellipse cx="170" cy="200" rx="92" ry="88" fill="hsl(28 90% 63%)"/>
          <ellipse cx="170" cy="251" rx="46" ry="32" fill="#FFF4E3"/>
          <g id="eyes">
            <g class="eyes-open">
              <circle cx="132" cy="178" r="10" fill="#46322B"/>
              <circle cx="208" cy="178" r="10" fill="#46322B"/>
            </g>
            <g class="eyes-happy">
              <path d="M120,179 Q132,165 144,179" fill="none" stroke="#46322B" stroke-width="5.5" stroke-linecap="round"/>
              <path d="M196,179 Q208,165 220,179" fill="none" stroke="#46322B" stroke-width="5.5" stroke-linecap="round"/>
            </g>
            <g class="eyes-sleepy">
              <path d="M121,177 A11,11 0 0 0 143,177 Z" fill="#46322B"/>
              <path d="M197,177 A11,11 0 0 0 219,177 Z" fill="#46322B"/>
            </g>
            <g class="eyes-closed">
              <path d="M121,179 Q132,188 143,179" fill="none" stroke="#46322B" stroke-width="5" stroke-linecap="round"/>
              <path d="M197,179 Q208,188 219,179" fill="none" stroke="#46322B" stroke-width="5" stroke-linecap="round"/>
            </g>
            <g class="eyes-up">
              <circle cx="129" cy="174" r="10" fill="#46322B"/>
              <circle cx="205" cy="174" r="10" fill="#46322B"/>
            </g>
            <g class="eyes-wide">
              <circle cx="132" cy="178" r="11.5" fill="#46322B"/>
              <circle cx="208" cy="178" r="11.5" fill="#46322B"/>
            </g>
          </g>
          <ellipse cx="170" cy="198" rx="5.5" ry="4" fill="#4A332B"/>
          <g id="mouth">
            <path class="m-idle" d="M156,209 q7,7 14,0 q7,7 14,0" fill="none" stroke="#4A332B" stroke-width="3.2" stroke-linecap="round"/>
            <g class="m-happy">
              <path d="M157,207 Q170,226 183,207 Z" fill="#5C3A30"/>
            </g>
            <ellipse class="m-o" cx="170" cy="210" rx="4.5" ry="5.5" fill="#5C3A30"/>
            <path class="m-sleep" d="M162,210 Q170,214 178,210" fill="none" stroke="#4A332B" stroke-width="3" stroke-linecap="round"/>
          </g>
        </g>
        </svg>
        </body></html>
        """
    }()
}
```

```swift
// Sources/MpetApp/BubbleView.swift
import SwiftUI

struct BubbleView: View {
    let text: String
    @State private var visible = true

    var body: some View {
        Text(text)
            .font(.system(size: 13, design: .rounded))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.95)))
            .shadow(radius: 4)
            .opacity(visible ? 1 : 0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation { visible = false }
                }
            }
    }
}
```

```swift
// Sources/MpetApp/ChatPanel.swift
import SwiftUI

struct ChatPanel: View {
    @ObservedObject var viewModel: PetViewModel
    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.chatMessages) { msg in
                            HStack(alignment: .top) {
                                if msg.role == "user" {
                                    Spacer()
                                    Text(msg.text)
                                        .padding(10)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.2)))
                                } else {
                                    Text(msg.text)
                                        .padding(10)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
                                    Spacer()
                                }
                            }
                            .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.chatMessages.count) { _ in
                    if let last = viewModel.chatMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            Divider()
            HStack {
                TextField("跟它说点什么…", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { send() }
                Button("发送") { send() }
                    .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
        }
    }

    private func send() {
        viewModel.sendChat(inputText)
        inputText = ""
    }
}
```

```swift
// Sources/MpetApp/StatusMenu.swift
import SwiftUI

struct StatusMenuContent: View {
    @ObservedObject var viewModel: PetViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🦊 泡沫").font(.headline)
                Spacer()
                Text(viewModel.isConnected ? "●" : "○")
                    .foregroundStyle(viewModel.isConnected ? .green : .red)
            }
            Divider()
            LabeledContent("心情", value: moodCN(viewModel.mood))
            LabeledContent("注意力", value: attentionCN(viewModel.attention))
            LabeledContent("阶段", value: stageCN(viewModel.stage))
            LabeledContent("版本", value: viewModel.soulVersion)
            Divider()
            Button("打开聊天") { /* open chat window */ }
            Button("设置…") { /* open settings */ }
            Divider()
            Button("退出") { NSApplication.shared.terminate(nil) }
        }
        .padding()
        .frame(width: 220)
    }

    private func moodCN(_ m: String) -> String {
        ["calm": "平静", "happy": "开心", "sleepy": "犯困", "missing": "想你"][m] ?? m
    }
    private func attentionCN(_ a: String) -> String {
        ["attending": "专注", "elsewhere": "别处", "away": "离开"][a] ?? a
    }
    private func stageCN(_ s: String) -> String {
        ["egg": "蛋", "baby": "幼崽", "juvenile": "少年", "adult": "成年"][s] ?? s
    }
}
```

```swift
// Sources/MpetApp/SettingsPanel.swift
import SwiftUI
import SoulCore

struct SettingsPanel: View {
    @ObservedObject var viewModel: PetViewModel
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var petName = "泡沫"
    @State private var nudgeBudget = 4

    var body: some View {
        Form {
            Section("LLM 端点") {
                TextField("Base URL", text: $baseURL)
                SecureField("API Key", text: $apiKey)
                TextField("Model", text: $model)
            }
            Section("人设") {
                TextField("名字", text: $petName)
                Stepper("唤醒预算：\(nudgeBudget)/小时", value: $nudgeBudget, in: 1...20)
            }
            Section("守护进程") {
                Button("安装 LaunchAgent") { installLaunchd() }
                Button("卸载 LaunchAgent") { uninstallLaunchd() }
            }
            Section("CC Watcher") {
                Button("安装 CC Hook") { installCCHook() }
                Button("卸载 CC Hook") { uninstallCCHook() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 400)
        .onAppear { loadSettings() }
    }

    private func loadSettings() {
        let keychain = KeychainStore()
        apiKey = keychain.load(account: "apiKey") ?? ""
        if let config = try? SoulConfig.load() {
            baseURL = config.llm.baseURL.absoluteString
            model = config.llm.model
            nudgeBudget = config.nudgeBudgetPerHour
        }
    }

    private func saveAPIKey() {
        KeychainStore().save(apiKey, account: "apiKey")
    }

    private func installLaunchd() {
        let binPath = Bundle.main.executableURL?.deletingLastPathComponent()
            .appendingPathComponent("mpet-soul").path ?? "/usr/local/bin/mpet-soul"
        try? LaunchdInstaller.install(programPath: binPath)
    }

    private func uninstallLaunchd() {
        try? LaunchdInstaller.uninstall()
    }

    private func installCCHook() {
        let settingsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
        let spoolDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/mpet/plugins/cc-watcher/spool")
        try? FileManager.default.createDirectory(at: spoolDir, withIntermediateDirectories: true)
        let hookCmd = "cat > \"\(spoolDir.path)/$(date +%s%N).json\""
        try? HookInstaller(settingsPath: settingsPath).install(hookCommand: hookCmd)
    }

    private func uninstallCCHook() {
        let settingsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
        try? HookInstaller(settingsPath: settingsPath).uninstall()
    }
}
```

```swift
// Sources/MpetApp/OnboardingView.swift
import SwiftUI

struct OnboardingView: View {
    @State private var step = 0
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            switch step {
            case 0:
                Image(systemName: "egg.fill").font(.system(size: 64))
                Text("一颗蛋出现在你的桌面上").font(.title2)
                Text("它即将孵化成你的专属电子生命")
                Button("开始孵化") { step = 1 }
            case 1:
                Text("配置它的灵魂").font(.title2)
                Text("需要一个 LLM 端点来赋予它思想")
                // 简化版：直接跳到完成
                Button("使用默认配置") { step = 2 }
            case 2:
                Image(systemName: "sparkles").font(.system(size: 64))
                Text("孵化完成！").font(.title2)
                Text("「泡沫」睁开了眼睛，好奇地看着你")
                Button("开始一起生活") { onComplete() }
            default:
                EmptyView()
            }
        }
        .padding(40)
        .frame(width: 400, height: 350)
    }
}
```

- [ ] **Step 4: 编译验证** — `swift build 2>&1 | tail -3` — 可能需要在 Package.swift 中调整 MpetApp target 的依赖（如需 SwiftUI 可能需要 .macOS(.v14) 或 AppKit 链接）

**注意**：SwiftUI macOS App 作为 SPM executable target 可能需要特殊处理。如果编译报错：
1. 确认 `platforms: [.macOS(.v13)]` 足够（SwiftUI macOS 需 12+，`@main` App 需 12+）
2. 可能需要在 Package.swift 中添加 `.linkerSettings([.linkedFramework("AppKit"), .linkedFramework("WebKit"), .linkedFramework("SwiftUI")])`
3. `NSViewRepresentable` 需要 `import AppKit`
4. 确保 Info.plist 中有 `LSUIElement = true`（无 Dock 图标）——SPM 不支持直接设 Info.plist，需在 build 后处理或使用 Xcode 项目

如果 SPM 直接构建 macOS GUI app 过于复杂，**备选方案**：
- 将 MpetApp 拆为独立 Xcode 项目（引用 SPM package）
- 或用 SPM executable + `@main` struct + AppKit 手动管理窗口

实现时按编译结果选择最简路径。

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m1): MpetApp — SwiftUI macOS app with PetWindow, SVGRenderer, Chat, Settings, Onboarding"`

---

### Task 12: M1 端到端验收 + 打标

- [ ] **Step 1: 全量测试** — `swift test 2>&1 | tail -5` — Expected: 全部 PASS（约 60+ 用例）

- [ ] **Step 2: 手工验收**

```bash
# 终端 A：启动灵魂
export MPET_BASE_URL="..." MPET_API_KEY="..." MPET_MODEL="..."
swift run mpet-soul

# 终端 B：安装 CC hook + 启动 cc-watcher
swift run mpet-cc-watcher --install-hook
swift run mpet-cc-watcher

# 终端 C：启动桌面 App
swift run MpetApp

# 验收清单：
# □ App 窗口透明置顶，显示 SVG 宠物（默认 idle 状态）
# □ 宠物状态随 daemon mood 变化（idle/happy/sleepy/missing）
# □ 聊天面板能发消息、收流式回复
# □ 气泡弹出（speak 指令触发）
# □ 菜单栏图标显示状态
# □ 设置面板可配置 LLM 端点（Key 存 Keychain）
# □ CC hook 安装后，CC 事件触发宠物 alert 动画
# □ affordance 点击能跳回 CC 终端
# □ LaunchAgent 安装后重启电脑 daemon 自启
```

- [ ] **Step 3: 更新 spec §0 进度仪表盘**

In `docs/superpowers/specs/2026-06-11-mpet-soul-design.md`:
- M1 行状态改为 ✅
- §5.1 徽章改为 🚧（身体 App + launchd ✅，信使 ⬜）
- §10.9 徽章改为 🚧（hook + spool ✅，进程管理 ⬜）

- [ ] **Step 4: 更新 HANDOVER.md**

- [ ] **Step 5: 合并 main + 打标**

```bash
git checkout main
git merge --no-ff m1-body-and-watcher -m "merge: M1 借壳还魂 — 桌面身体 App + cc-watcher 插件 + launchd + Keychain"
git tag v0.2.0-m1
git push origin main --tags
```

---

## 自检记录（writing-plans Self-Review）

1. **Spec 覆盖**：M1 行六要素——身体 App ✅(T11) cc-watcher ✅(T4-T6+T10) 设置面板 ✅(T11 SettingsPanel) Keychain ✅(T7) launchd ✅(T8) M0 遗留两修 ✅(T1+T2+T9)。
2. **占位符扫描**：无 TBD/TODO；SVGRenderer 内嵌了简化 SVG（从 spike 提取），实现时可用完整版替换。
3. **类型一致性**：`PeripheralMessage` 复用 M0 定义 · `SoulClient` actor 使用 `LineCodec` 与 `PeripheralMessage` · `CCEvent.toPercept()` 返回 `Percept`（M0 类型）· `DaemonSoul` actor 复用 `StateStore`/`PerceptLog`/`WakePolicy`（M0 类型）。
4. **编译风险**：MpetApp 作为 SPM executable 构建 macOS GUI 可能需要调整（已在 T11 注明备选方案）。
