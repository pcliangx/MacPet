# M0 灵魂胚胎 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 一个 headless 的灵魂守护进程：事件驱动的 LLM agent 循环（OpenAI 兼容工具调用）+ 感知收件箱 + 反射弧 + 外设 NDJSON 协议族 v0，用 `soulctl` 在终端里看它想事、跟它说话。

**Architecture:** `SoulCore`（纯逻辑库，全单测，时钟可注入，假 LLM 测试架）+ `mpet-soul`（daemon 薄壳：Unix socket + 在场感知 + 接线）+ `soulctl`（调试客户端，兼协议狗粮）。一切按 spec v2.5 §5/§13 M0 行执行；**不引用旧仓库任何代码（已废弃）**。

**Tech Stack:** Swift 5.9 / SPM / macOS 13+，零第三方依赖（Foundation + Network.framework）。测试 XCTest。

**对应 spec 条目：** §5.1 进程形态（daemon+外设）、§5.2 大脑（agent 循环/感知器/唤醒策略/工具箱/反射弧/聊天合一）、§10.1-10.3 外设协议 v0（含 fuel/affordance 信封，M0 只定义不消费）、§12.1 能力探测、§12.2 原子写+版本化、§12.5 可注入时钟、风险清单的"一颗心并发模型/假 LLM 测试架/结算对账原语"。

---

## 文件结构（先锁边界）

```
Package.swift
Sources/SoulCore/
  Time/SoulClock.swift            # 时钟协议 + SystemClock + TestClock（时间旅行）
  Time/DayRollover.swift          # 跨天/补结算原语
  Protocol/JSONValue.swift        # 任意 JSON 值（payload/工具参数的通用载体）
  Protocol/PeripheralMessage.swift# 外设消息信封（t 字段路由，容忍未知）
  Protocol/LineCodec.swift        # NDJSON 帧编解码
  Perception/Percept.swift        # 感知事件（kind/priority/actions）
  Perception/PerceptLog.swift     # 近期感知环形缓冲 + 合并
  Reflex/Attention.swift          # 在场快照 → attending/elsewhere/away
  Reflex/Mood.swift               # 四心情纯函数引擎
  Reflex/ReflexArc.swift          # 注意力×优先级 → 反应强度 → 即时指令
  Brain/LLMContracts.swift        # ChatMessage/ToolCall/ToolSpec/LLMConfig/LLMProviding
  Brain/ScriptedLLM.swift         # 假 LLM（脚本化回合，可注入延迟）
  Brain/OpenAILLMClient.swift     # OpenAI 兼容流式 + 工具调用
  Brain/ToolRegistry.swift        # 工具注册表（tier/stage 门控字段）+ speak/emote
  Brain/PersonaSynth.swift        # 人格合成块 v0（基因+阶段+心情 → system prompt）
  Brain/WakePolicy.swift          # 唤醒策略（alert 直通 / nudge 预算 / ambient 不醒）
  Brain/Mind.swift                # 一颗心 actor：交互快车道抢占后台、可取消、回滚
  State/SoulState.swift           # 心情/最近互动/醒来要说的话 + schemaVersion
  State/StateStore.swift          # 原子写 + 容忍解码 + 每日备份轮转
  Probe/CapabilityProbe.swift     # 端点能力探测（工具调用/参数保真/流式）
Sources/mpet-soul/
  main.swift                      # --foreground；配置加载；全部接线
  SocketServer.swift              # Unix socket NDJSON 服务（NWListener）
  PresenceSensorMac.swift         # NSWorkspace 前台 + CGEventSource 空闲
  SoulConfig.swift                # ~/.config/mpet/soul.json + 环境变量覆盖
Sources/soulctl/
  main.swift                      # status / chat / event / sense / probe
Tests/SoulCoreTests/              # 每个组件一个测试文件（文件名 = 组件名+Tests）
```

**M0 不做**（防镀金）：成长/XP、记忆工具、做梦、插件进程管理、courier、launchd 安装、Keychain（M0 配置文件读 key）、对端 uid 校验（socket 以 0700 目录 + 0600 文件权限保护，uid 校验列入 M1 加固）。

---

### Task 0: SPM 脚手架

**Files:** Create: `Package.swift`, `.gitignore`, `Sources/SoulCore/SoulCore.swift`, `Sources/mpet-soul/main.swift`, `Sources/soulctl/main.swift`, `Tests/SoulCoreTests/SanityTests.swift`

- [ ] **Step 1: 写 Package.swift 与占位源文件**

```swift
// Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "mpet",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "SoulCore"),
        .executableTarget(name: "mpet-soul", dependencies: ["SoulCore"]),
        .executableTarget(name: "soulctl", dependencies: ["SoulCore"]),
        .testTarget(name: "SoulCoreTests", dependencies: ["SoulCore"]),
    ]
)
```

```swift
// Sources/SoulCore/SoulCore.swift
public enum SoulCoreInfo { public static let version = "0.1.0-m0" }
```

```swift
// Sources/mpet-soul/main.swift
print("mpet-soul \(SoulCoreInfo.version)")
import SoulCore
```

```swift
// Sources/soulctl/main.swift
print("soulctl \(SoulCoreInfo.version)")
import SoulCore
```

```swift
// Tests/SoulCoreTests/SanityTests.swift
import XCTest
@testable import SoulCore

final class SanityTests: XCTestCase {
    func testVersion() { XCTAssertEqual(SoulCoreInfo.version, "0.1.0-m0") }
}
```

```gitignore
.build/
.swiftpm/
*.xcodeproj
.DS_Store
```

注意：`main.swift` 顶层代码中 `import` 必须在文件首行——上面两个可执行占位写成 `import SoulCore` 在前、`print` 在后。

- [ ] **Step 2: 构建并跑测试**

Run: `cd /Users/pc2026/Documents/DevTools/MacPet && swift test 2>&1 | tail -3`
Expected: `Test Suite 'All tests' passed`（1 个用例）

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "chore(m0): SPM scaffold — SoulCore + mpet-soul + soulctl + tests"
```

---

### Task 1: SoulClock + DayRollover（可注入时钟与补结算原语）

**Files:** Create: `Sources/SoulCore/Time/SoulClock.swift`, `Sources/SoulCore/Time/DayRollover.swift`; Test: `Tests/SoulCoreTests/SoulClockTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class SoulClockTests: XCTestCase {
    func testTestClockAdvances() {
        let t0 = Date(timeIntervalSince1970: 1_750_000_000)
        let clock = TestClock(t0)
        clock.advance(by: 3600)
        XCTAssertEqual(clock.now.timeIntervalSince(t0), 3600)
    }
    func testMissedDaysAcrossSleep() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let f = ISO8601DateFormatter()
        let last = f.date(from: "2026-06-08T23:50:00+08:00")!
        let now  = f.date(from: "2026-06-11T00:10:00+08:00")!
        XCTAssertEqual(DayRollover.missedDays(from: last, to: now, calendar: cal), 3)
        XCTAssertEqual(DayRollover.missedDays(from: now, to: now, calendar: cal), 0)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter SoulClockTests 2>&1 | tail -3` — Expected: 编译失败 `cannot find 'TestClock'`

- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Time/SoulClock.swift
import Foundation

public protocol SoulClock: Sendable { var now: Date { get } }

public struct SystemClock: SoulClock {
    public init() {}
    public var now: Date { Date() }
}

/// 时间旅行测试时钟（开发模式硬约束 §12.5 的根基）
public final class TestClock: SoulClock, @unchecked Sendable {
    private let lock = NSLock()
    private var t: Date
    public init(_ start: Date) { t = start }
    public var now: Date { lock.lock(); defer { lock.unlock() }; return t }
    public func advance(by seconds: TimeInterval) {
        lock.lock(); t = t.addingTimeInterval(seconds); lock.unlock()
    }
}
```

```swift
// Sources/SoulCore/Time/DayRollover.swift
import Foundation

public enum DayRollover {
    /// 上次活跃日与现在之间隔了几个"天边界"——睡眠/时区跳变后的补结算依据
    public static func missedDays(from last: Date, to now: Date, calendar: Calendar = .current) -> Int {
        let a = calendar.startOfDay(for: last)
        let b = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: a, to: b).day ?? 0)
    }
}
```

- [ ] **Step 4: 跑测试确认通过** — Run: `swift test --filter SoulClockTests 2>&1 | tail -3` — Expected: PASS
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m0): injectable SoulClock + DayRollover reconciliation primitive"`

---

### Task 2: JSONValue + 外设消息信封 + NDJSON 编解码

**Files:** Create: `Sources/SoulCore/Protocol/JSONValue.swift`, `Sources/SoulCore/Protocol/PeripheralMessage.swift`, `Sources/SoulCore/Protocol/LineCodec.swift`; Test: `Tests/SoulCoreTests/ProtocolTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
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
```

- [ ] **Step 2: 确认失败** — Run: `swift test --filter ProtocolTests 2>&1 | tail -3` — Expected: 编译失败
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Protocol/JSONValue.swift
import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String), number(Double), bool(Bool), null
    case array([JSONValue]), object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "unsupported JSON") }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b):   try c.encode(b)
        case .null:          try c.encodeNil()
        case .array(let a):  try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
    public var stringValue: String? { if case .string(let s) = self { return s }; return nil }
}
```

```swift
// Sources/SoulCore/Protocol/PeripheralMessage.swift
import Foundation

public struct PerceptAction: Codable, Equatable, Sendable {
    public let id: String, label: String
    public init(id: String, label: String) { self.id = id; self.label = label }
}

public enum PerceptPriority: String, Codable, Sendable { case ambient, nudge, alert }

public struct Percept: Codable, Equatable, Sendable {
    public let id: String
    public let kind: String
    public let priority: PerceptPriority
    public let payload: [String: JSONValue]
    public let actions: [PerceptAction]
    public let at: Date
    public init(id: String = UUID().uuidString, kind: String, priority: PerceptPriority,
                payload: [String: JSONValue] = [:], actions: [PerceptAction] = [], at: Date) {
        self.id = id; self.kind = kind; self.priority = priority
        self.payload = payload; self.actions = actions; self.at = at
    }
}

/// 外设协议族 v0（spec §10.3）。t 字段路由；未知类型容忍为 .unknown。
public enum PeripheralMessage: Equatable, Sendable {
    case hello(role: String, name: String, proto: Int)
    case helloOK(proto: Int, soulVersion: String)
    case event(kind: String, payload: [String: JSONValue])        // 身体事件上行
    case senseEvent(Percept)                                      // 插件感官上行
    case chatUser(text: String)
    case chatDelta(text: String)
    case chatDone
    case directive(kind: String, payload: [String: JSONValue])    // 灵魂指令下行
    case toolCall(id: String, name: String, args: [String: JSONValue])
    case toolResult(id: String, ok: Bool, content: JSONValue)
    case fuelReport(date: String, raw: Double)                    // M3 消费，信封先定
    case actionInvoke(eventId: String, actionId: String)          // affordance 回调
    case status
    case statusOK([String: JSONValue])
    case ping, pong, bye
    case unknown(t: String)
}

extension PeripheralMessage: Codable {
    private enum K: String, CodingKey {
        case t, role, name, proto, soulVersion, kind, payload, percept, text,
             id, args, ok, content, date, raw, eventId, actionId, fields
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        let t = try c.decode(String.self, forKey: .t)
        switch t {
        case "hello": self = .hello(role: try c.decode(String.self, forKey: .role),
                                    name: try c.decode(String.self, forKey: .name),
                                    proto: try c.decode(Int.self, forKey: .proto))
        case "hello.ok": self = .helloOK(proto: try c.decode(Int.self, forKey: .proto),
                                         soulVersion: try c.decode(String.self, forKey: .soulVersion))
        case "event": self = .event(kind: try c.decode(String.self, forKey: .kind),
                                    payload: try c.decodeIfPresent([String: JSONValue].self, forKey: .payload) ?? [:])
        case "sense.event": self = .senseEvent(try c.decode(Percept.self, forKey: .percept))
        case "chat.user": self = .chatUser(text: try c.decode(String.self, forKey: .text))
        case "chat.delta": self = .chatDelta(text: try c.decode(String.self, forKey: .text))
        case "chat.done": self = .chatDone
        case "directive": self = .directive(kind: try c.decode(String.self, forKey: .kind),
                                            payload: try c.decodeIfPresent([String: JSONValue].self, forKey: .payload) ?? [:])
        case "tool.call": self = .toolCall(id: try c.decode(String.self, forKey: .id),
                                           name: try c.decode(String.self, forKey: .name),
                                           args: try c.decodeIfPresent([String: JSONValue].self, forKey: .args) ?? [:])
        case "tool.result": self = .toolResult(id: try c.decode(String.self, forKey: .id),
                                               ok: try c.decode(Bool.self, forKey: .ok),
                                               content: try c.decodeIfPresent(JSONValue.self, forKey: .content) ?? .null)
        case "fuel.report": self = .fuelReport(date: try c.decode(String.self, forKey: .date),
                                               raw: try c.decode(Double.self, forKey: .raw))
        case "action.invoke": self = .actionInvoke(eventId: try c.decode(String.self, forKey: .eventId),
                                                   actionId: try c.decode(String.self, forKey: .actionId))
        case "status": self = .status
        case "status.ok": self = .statusOK(try c.decodeIfPresent([String: JSONValue].self, forKey: .fields) ?? [:])
        case "ping": self = .ping
        case "pong": self = .pong
        case "bye": self = .bye
        default: self = .unknown(t: t)
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        switch self {
        case .hello(let role, let name, let proto):
            try c.encode("hello", forKey: .t); try c.encode(role, forKey: .role)
            try c.encode(name, forKey: .name); try c.encode(proto, forKey: .proto)
        case .helloOK(let proto, let v):
            try c.encode("hello.ok", forKey: .t); try c.encode(proto, forKey: .proto)
            try c.encode(v, forKey: .soulVersion)
        case .event(let kind, let payload):
            try c.encode("event", forKey: .t); try c.encode(kind, forKey: .kind)
            try c.encode(payload, forKey: .payload)
        case .senseEvent(let p):
            try c.encode("sense.event", forKey: .t); try c.encode(p, forKey: .percept)
        case .chatUser(let s): try c.encode("chat.user", forKey: .t); try c.encode(s, forKey: .text)
        case .chatDelta(let s): try c.encode("chat.delta", forKey: .t); try c.encode(s, forKey: .text)
        case .chatDone: try c.encode("chat.done", forKey: .t)
        case .directive(let kind, let payload):
            try c.encode("directive", forKey: .t); try c.encode(kind, forKey: .kind)
            try c.encode(payload, forKey: .payload)
        case .toolCall(let id, let name, let args):
            try c.encode("tool.call", forKey: .t); try c.encode(id, forKey: .id)
            try c.encode(name, forKey: .name); try c.encode(args, forKey: .args)
        case .toolResult(let id, let ok, let content):
            try c.encode("tool.result", forKey: .t); try c.encode(id, forKey: .id)
            try c.encode(ok, forKey: .ok); try c.encode(content, forKey: .content)
        case .fuelReport(let date, let raw):
            try c.encode("fuel.report", forKey: .t); try c.encode(date, forKey: .date)
            try c.encode(raw, forKey: .raw)
        case .actionInvoke(let e, let a):
            try c.encode("action.invoke", forKey: .t); try c.encode(e, forKey: .eventId)
            try c.encode(a, forKey: .actionId)
        case .status: try c.encode("status", forKey: .t)
        case .statusOK(let f): try c.encode("status.ok", forKey: .t); try c.encode(f, forKey: .fields)
        case .ping: try c.encode("ping", forKey: .t)
        case .pong: try c.encode("pong", forKey: .t)
        case .bye: try c.encode("bye", forKey: .t)
        case .unknown(let t): try c.encode(t, forKey: .t)
        }
    }
}
```

```swift
// Sources/SoulCore/Protocol/LineCodec.swift
import Foundation

/// NDJSON：一行一个 JSON 消息。带缓冲的流式拆帧。
public struct LineCodec {
    private var buffer = Data()
    public init() {}

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    public static func encode(_ m: PeripheralMessage) throws -> Data {
        var d = try encoder.encode(m); d.append(UInt8(ascii: "\n")); return d
    }
    public static func decodeLine(_ data: Data) throws -> PeripheralMessage {
        try decoder.decode(PeripheralMessage.self, from: data)
    }
    /// 喂入任意分片，返回完整消息列表
    public mutating func feed(_ chunk: Data) throws -> [PeripheralMessage] {
        buffer.append(chunk)
        var out: [PeripheralMessage] = []
        while let nl = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer.subdata(in: buffer.startIndex..<nl)
            buffer.removeSubrange(buffer.startIndex...nl)
            if !line.isEmpty { out.append(try Self.decodeLine(line)) }
        }
        return out
    }
}
```

- [ ] **Step 4: 确认通过** — Run: `swift test --filter ProtocolTests 2>&1 | tail -3` — Expected: PASS（3 用例）
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m0): peripheral protocol v0 — envelope (sense/tool/fuel/affordance) + NDJSON codec"`

---

### Task 3: PerceptLog（近期感知环形缓冲 + 合并）

**Files:** Create: `Sources/SoulCore/Perception/PerceptLog.swift`; Test: `Tests/SoulCoreTests/PerceptLogTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class PerceptLogTests: XCTestCase {
    func testCoalescesSameKindAmbientWithinWindow() {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let log = PerceptLog(capacity: 10, coalesceWindow: 60, clock: clock)
        log.add(Percept(kind: "weather.tick", priority: .ambient, at: clock.now))
        clock.advance(by: 10)
        log.add(Percept(kind: "weather.tick", priority: .ambient, at: clock.now))
        XCTAssertEqual(log.recent(limit: 10).count, 1)          // 合并了
        clock.advance(by: 120)
        log.add(Percept(kind: "weather.tick", priority: .ambient, at: clock.now))
        XCTAssertEqual(log.recent(limit: 10).count, 2)          // 窗口外不合并
    }
    func testAlertNeverCoalescedAndCapacityBounds() {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let log = PerceptLog(capacity: 3, coalesceWindow: 60, clock: clock)
        for _ in 0..<5 { log.add(Percept(kind: "cc.waiting", priority: .alert, at: clock.now)) }
        XCTAssertEqual(log.recent(limit: 10).count, 3)          // 容量封顶，alert 不合并
    }
}
```

- [ ] **Step 2: 确认失败** — Run: `swift test --filter PerceptLogTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Perception/PerceptLog.swift
import Foundation

/// 近期感知环形缓冲：唤醒时的「近期事件摘要」来源。ambient 同类合并防事件风暴。
public final class PerceptLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [Percept] = []
    private let capacity: Int
    private let coalesceWindow: TimeInterval
    private let clock: SoulClock

    public init(capacity: Int = 50, coalesceWindow: TimeInterval = 60, clock: SoulClock) {
        self.capacity = capacity; self.coalesceWindow = coalesceWindow; self.clock = clock
    }
    public func add(_ p: Percept) {
        lock.lock(); defer { lock.unlock() }
        if p.priority == .ambient,
           let last = items.last, last.kind == p.kind, last.priority == .ambient,
           clock.now.timeIntervalSince(last.at) < coalesceWindow {
            items[items.count - 1] = p          // 合并：保留最新
            return
        }
        items.append(p)
        if items.count > capacity { items.removeFirst(items.count - capacity) }
    }
    public func recent(limit: Int) -> [Percept] {
        lock.lock(); defer { lock.unlock() }
        return Array(items.suffix(limit))
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter PerceptLogTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m0): PerceptLog ring buffer with ambient coalescing"`

---

### Task 4: Attention（在场 → 注意力三态）

**Files:** Create: `Sources/SoulCore/Reflex/Attention.swift`; Test: `Tests/SoulCoreTests/AttentionTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class AttentionTests: XCTestCase {
    let watched: Set<String> = ["com.apple.Terminal", "com.googlecode.iterm2"]
    func testIdleMeansAway() {
        let s = PresenceSnapshot(frontmostBundleID: "com.apple.Terminal", idleSeconds: 300, watchedBundleIDs: watched)
        XCTAssertEqual(AttentionResolver.resolve(s), .away)
    }
    func testWatchedFrontmostMeansAttending() {
        let s = PresenceSnapshot(frontmostBundleID: "com.googlecode.iterm2", idleSeconds: 5, watchedBundleIDs: watched)
        XCTAssertEqual(AttentionResolver.resolve(s), .attending)
    }
    func testOtherwiseElsewhere() {
        let s = PresenceSnapshot(frontmostBundleID: "com.apple.Safari", idleSeconds: 5, watchedBundleIDs: watched)
        XCTAssertEqual(AttentionResolver.resolve(s), .elsewhere)
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter AttentionTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Reflex/Attention.swift
import Foundation

public enum Attention: String, Codable, Sendable { case attending, elsewhere, away }

public struct PresenceSnapshot: Equatable, Sendable {
    public let frontmostBundleID: String?
    public let idleSeconds: TimeInterval
    public let watchedBundleIDs: Set<String>
    public init(frontmostBundleID: String?, idleSeconds: TimeInterval, watchedBundleIDs: Set<String>) {
        self.frontmostBundleID = frontmostBundleID
        self.idleSeconds = idleSeconds
        self.watchedBundleIDs = watchedBundleIDs
    }
}

public enum AttentionResolver {
    public static func resolve(_ s: PresenceSnapshot, awayThreshold: TimeInterval = 180) -> Attention {
        if s.idleSeconds >= awayThreshold { return .away }
        if let f = s.frontmostBundleID, s.watchedBundleIDs.contains(f) { return .attending }
        return .elsewhere
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter AttentionTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m0): attention resolver (attending/elsewhere/away)"`

---

### Task 5: MoodEngine（四心情纯函数）

**Files:** Create: `Sources/SoulCore/Reflex/Mood.swift`; Test: `Tests/SoulCoreTests/MoodTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class MoodTests: XCTestCase {
    func testLongAwayMeansMissing() {
        let m = MoodEngine.mood(.init(attention: .away, hour: 15, secondsSinceInteraction: 3 * 3600))
        XCTAssertEqual(m, .missing)
    }
    func testNightMeansSleepy() {
        let m = MoodEngine.mood(.init(attention: .attending, hour: 1, secondsSinceInteraction: 3600))
        XCTAssertEqual(m, .sleepy)
    }
    func testRecentInteractionMeansHappy() {
        let m = MoodEngine.mood(.init(attention: .attending, hour: 15, secondsSinceInteraction: 120))
        XCTAssertEqual(m, .happy)
    }
    func testDefaultCalm() {
        let m = MoodEngine.mood(.init(attention: .elsewhere, hour: 15, secondsSinceInteraction: 3600))
        XCTAssertEqual(m, .calm)
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter MoodTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Reflex/Mood.swift
import Foundation

public enum Mood: String, Codable, Sendable { case calm, happy, sleepy, missing }

public struct MoodInputs: Sendable {
    public let attention: Attention
    public let hour: Int                      // 0-23，本地时
    public let secondsSinceInteraction: TimeInterval
    public init(attention: Attention, hour: Int, secondsSinceInteraction: TimeInterval) {
        self.attention = attention; self.hour = hour
        self.secondsSinceInteraction = secondsSinceInteraction
    }
}

/// v0 优先序：想你 > 困 > 开心 > 平静。夜窗固定 23-5 点（M3 作息自适应后改为学习值）。
public enum MoodEngine {
    public static func mood(_ i: MoodInputs, nightHours: Set<Int> = [23, 0, 1, 2, 3, 4, 5]) -> Mood {
        if i.attention == .away && i.secondsSinceInteraction >= 2 * 3600 { return .missing }
        if nightHours.contains(i.hour) { return .sleepy }
        if i.secondsSinceInteraction <= 10 * 60 { return .happy }
        return .calm
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter MoodTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m0): four-mood engine (calm/happy/sleepy/missing)"`

---

### Task 6: ReflexArc（注意力 × 优先级 → 反应强度与即时指令）

**Files:** Create: `Sources/SoulCore/Reflex/ReflexArc.swift`; Test: `Tests/SoulCoreTests/ReflexArcTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class ReflexArcTests: XCTestCase {
    func testIntensityTable() {
        XCTAssertEqual(ReflexArc.intensity(attention: .attending, priority: .alert), .animate)
        XCTAssertEqual(ReflexArc.intensity(attention: .elsewhere, priority: .alert), .sound)
        XCTAssertEqual(ReflexArc.intensity(attention: .away,      priority: .alert), .notify)
        XCTAssertEqual(ReflexArc.intensity(attention: .attending, priority: .nudge), .silent)
        XCTAssertEqual(ReflexArc.intensity(attention: .away,      priority: .nudge), .animate)
        XCTAssertEqual(ReflexArc.intensity(attention: .attending, priority: .ambient), .silent)
    }
    func testAlertProducesNotifyDirectiveWhenAway() {
        let p = Percept(kind: "cc.waiting", priority: .alert,
                        payload: ["title": .string("CC 在等你")], at: Date())
        let ds = ReflexArc.directives(for: p, attention: .away, mood: .calm)
        guard case .directive(let kind, let payload) = ds.last else { return XCTFail("no directive") }
        XCTAssertEqual(kind, "notify")
        XCTAssertEqual(payload["title"]?.stringValue, "CC 在等你")
        // 任何非 silent 反应都先有身体动画
        guard case .directive(let k0, _) = ds.first else { return XCTFail() }
        XCTAssertEqual(k0, "emote")
    }
    func testAmbientProducesNothing() {
        let p = Percept(kind: "weather.tick", priority: .ambient, at: Date())
        XCTAssertTrue(ReflexArc.directives(for: p, attention: .attending, mood: .calm).isEmpty)
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter ReflexArcTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Reflex/ReflexArc.swift
import Foundation

public enum ReactionIntensity: Int, Codable, Sendable, Comparable {
    case silent = 0, animate = 1, sound = 2, notify = 3
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// 旧设想中 Orchestrator 的通用化：任何来源的事件按 注意力×优先级 享受同一套喊人梯度（spec §5.2）
public enum ReflexArc {
    public static func intensity(attention: Attention, priority: PerceptPriority) -> ReactionIntensity {
        switch (priority, attention) {
        case (.alert, .attending): return .animate
        case (.alert, .elsewhere): return .sound
        case (.alert, .away):      return .notify
        case (.nudge, .attending): return .silent
        case (.nudge, _):          return .animate
        case (.ambient, _):        return .silent
        }
    }

    /// 零成本即时身体指令（不经 LLM）。强度逐级叠加：emote → +sound → +notify。
    public static func directives(for p: Percept, attention: Attention, mood: Mood) -> [PeripheralMessage] {
        let level = intensity(attention: attention, priority: p.priority)
        guard level > .silent else { return [] }
        var out: [PeripheralMessage] = [
            .directive(kind: "emote", payload: ["animation": .string("alert"), "mood": .string(mood.rawValue)])
        ]
        if level >= .sound {
            out.append(.directive(kind: "sound", payload: ["name": .string("chirp")]))
        }
        if level >= .notify {
            let title = p.payload["title"]?.stringValue ?? p.kind
            out.append(.directive(kind: "notify", payload: [
                "title": .string(title),
                "perceptId": .string(p.id),
                "actions": .array(p.actions.map { .object(["id": .string($0.id), "label": .string($0.label)]) }),
            ]))
        }
        return out
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter ReflexArcTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m0): generalized reflex arc — attention × priority escalation ladder"`

---

### Task 7: LLM 契约（ChatMessage / ToolCall / ToolSpec / LLMConfig / LLMProviding）

**Files:** Create: `Sources/SoulCore/Brain/LLMContracts.swift`; Test: `Tests/SoulCoreTests/LLMContractsTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class LLMContractsTests: XCTestCase {
    func testChatMessageWireFormat() throws {
        let m = ChatMessage(role: .assistant, content: nil,
                            toolCalls: [ToolCall(id: "c1", name: "speak", arguments: #"{"text":"hi"}"#)])
        let data = try JSONEncoder().encode(m)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains(#""role":"assistant""#))
        XCTAssertTrue(json.contains(#""tool_calls""#))          // OpenAI 线格式 snake_case
        XCTAssertTrue(json.contains(#""function""#))
        let back = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(back, m)
    }
    func testToolMessageCarriesCallID() throws {
        let m = ChatMessage.toolResult(callID: "c1", content: "ok")
        let json = String(data: try JSONEncoder().encode(m), encoding: .utf8)!
        XCTAssertTrue(json.contains(#""tool_call_id":"c1""#))
    }
    func testLLMConfigTolerantDecode() throws {
        let raw = #"{"baseURL":"https://api.x.com/v1","apiKey":"k","model":"m","futureField":1}"#
        let cfg = try JSONDecoder().decode(LLMConfig.self, from: Data(raw.utf8))
        XCTAssertEqual(cfg.model, "m")
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter LLMContractsTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Brain/LLMContracts.swift
import Foundation

public struct ToolCall: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let arguments: String              // OpenAI 线格式：参数是 JSON 字符串
    public init(id: String, name: String, arguments: String) {
        self.id = id; self.name = name; self.arguments = arguments
    }
    private enum K: String, CodingKey { case id, type, function }
    private enum F: String, CodingKey { case name, arguments }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        id = try c.decode(String.self, forKey: .id)
        let f = try c.nestedContainer(keyedBy: F.self, forKey: .function)
        name = try f.decode(String.self, forKey: .name)
        arguments = try f.decodeIfPresent(String.self, forKey: .arguments) ?? "{}"
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(id, forKey: .id)
        try c.encode("function", forKey: .type)
        var f = c.nestedContainer(keyedBy: F.self, forKey: .function)
        try f.encode(name, forKey: .name)
        try f.encode(arguments, forKey: .arguments)
    }
}

public struct ChatMessage: Codable, Equatable, Sendable {
    public enum Role: String, Codable, Sendable { case system, user, assistant, tool }
    public var role: Role
    public var content: String?
    public var toolCalls: [ToolCall]?
    public var toolCallID: String?
    private enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
        case toolCallID = "tool_call_id"
    }
    public init(role: Role, content: String?, toolCalls: [ToolCall]? = nil, toolCallID: String? = nil) {
        self.role = role; self.content = content
        self.toolCalls = toolCalls; self.toolCallID = toolCallID
    }
    public static func system(_ s: String) -> ChatMessage { .init(role: .system, content: s) }
    public static func user(_ s: String) -> ChatMessage { .init(role: .user, content: s) }
    public static func toolResult(callID: String, content: String) -> ChatMessage {
        .init(role: .tool, content: content, toolCallID: callID)
    }
}

public enum ToolTier: String, Codable, Sendable { case freeHome = "free-home", freeRead = "free-read", ask, never }
public enum Stage: Int, Codable, Sendable, Comparable {
    case egg = 0, baby = 1, juvenile = 2, adult = 3
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

public struct ToolSpec: Equatable, Sendable {
    public let name: String
    public let description: String
    public let parametersJSON: String         // JSON Schema 字符串
    public let tier: ToolTier
    public let minStage: Stage
    public init(name: String, description: String, parametersJSON: String,
                tier: ToolTier = .freeHome, minStage: Stage = .baby) {
        self.name = name; self.description = description
        self.parametersJSON = parametersJSON; self.tier = tier; self.minStage = minStage
    }
}

public struct LLMConfig: Codable, Equatable, Sendable {
    public var baseURL: URL
    public var apiKey: String
    public var model: String
    private enum CodingKeys: String, CodingKey { case baseURL, apiKey, model }  // 容忍多余字段
    public init(baseURL: URL, apiKey: String, model: String) {
        self.baseURL = baseURL; self.apiKey = apiKey; self.model = model
    }
}

/// 大脑供应商：流式文本经 onDelta，返回最终 assistant 消息（可能携带工具调用）
public protocol LLMProviding: Sendable {
    func complete(messages: [ChatMessage], tools: [ToolSpec],
                  onDelta: @escaping @Sendable (String) -> Void) async throws -> ChatMessage
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter LLMContractsTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m0): LLM contracts — OpenAI wire-format messages, tool specs, provider protocol"`

---

### Task 8: ScriptedLLM（假 LLM 测试架）

**Files:** Create: `Sources/SoulCore/Brain/ScriptedLLM.swift`; Test: `Tests/SoulCoreTests/ScriptedLLMTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class ScriptedLLMTests: XCTestCase {
    func testPopsTurnsAndRecordsRequests() async throws {
        let fake = ScriptedLLM(turns: [
            ChatMessage(role: .assistant, content: nil,
                        toolCalls: [ToolCall(id: "c1", name: "speak", arguments: #"{"text":"嘞！"}"#)]),
            ChatMessage(role: .assistant, content: "好啦"),
        ])
        var deltas: [String] = []
        let r1 = try await fake.complete(messages: [.user("hi")], tools: [], onDelta: { deltas.append($0) })
        XCTAssertEqual(r1.toolCalls?.first?.name, "speak")
        let r2 = try await fake.complete(messages: [], tools: [], onDelta: { _ in })
        XCTAssertEqual(r2.content, "好啦")
        let seen = await fake.requests
        XCTAssertEqual(seen.count, 2)
        XCTAssertEqual(deltas, [])                       // 工具回合不发文本 delta
    }
    func testStreamsContentAsDeltas() async throws {
        let fake = ScriptedLLM(turns: [ChatMessage(role: .assistant, content: "你好呀")])
        var got = ""
        _ = try await fake.complete(messages: [], tools: [], onDelta: { got += $0 })
        XCTAssertEqual(got, "你好呀")
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter ScriptedLLMTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Brain/ScriptedLLM.swift
import Foundation

/// 测试架核心：脚本化回合、记录请求、可注入延迟（用于抢占/取消测试）
public actor ScriptedLLM: LLMProviding {
    public private(set) var requests: [[ChatMessage]] = []
    private var turns: [ChatMessage]
    private let delayNanos: UInt64

    public init(turns: [ChatMessage], delayNanos: UInt64 = 0) {
        self.turns = turns; self.delayNanos = delayNanos
    }

    public func complete(messages: [ChatMessage], tools: [ToolSpec],
                         onDelta: @escaping @Sendable (String) -> Void) async throws -> ChatMessage {
        requests.append(messages)
        if delayNanos > 0 { try await Task.sleep(nanoseconds: delayNanos) }
        try Task.checkCancellation()
        guard !turns.isEmpty else { return ChatMessage(role: .assistant, content: "…") }
        let turn = turns.removeFirst()
        if let text = turn.content, turn.toolCalls == nil {
            for ch in text { onDelta(String(ch)) }      // 逐字符模拟流式
        }
        return turn
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter ScriptedLLMTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m0): ScriptedLLM fake provider (scripted turns, request log, injectable delay)"`

---

### Task 9: OpenAILLMClient（流式 SSE + 工具调用增量组装）

**Files:** Create: `Sources/SoulCore/Brain/OpenAILLMClient.swift`; Test: `Tests/SoulCoreTests/OpenAILLMClientTests.swift`

- [ ] **Step 1: 写失败测试（URLProtocol 桩喂 SSE 分片）**

```swift
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
        // 请求体里带了 tools 与 stream
        let body = String(data: StubURLProtocol.lastBody ?? Data(), encoding: .utf8)!
        XCTAssertTrue(body.contains(#""stream":true"#))
        XCTAssertTrue(body.contains(#""tools""#))
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter OpenAILLMClientTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Brain/OpenAILLMClient.swift
import Foundation

/// OpenAI 兼容 chat/completions 客户端：流式 SSE + 工具调用。永不写死厂商（spec §12.1）。
public final class OpenAILLMClient: LLMProviding, @unchecked Sendable {
    private let config: LLMConfig
    private let session: URLSession
    public init(config: LLMConfig, session: URLSession = .shared) {
        self.config = config; self.session = session
    }

    public func complete(messages: [ChatMessage], tools: [ToolSpec],
                         onDelta: @escaping @Sendable (String) -> Void) async throws -> ChatMessage {
        var req = URLRequest(url: config.baseURL.appendingPathComponent("chat/completions"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try Self.requestBody(model: config.model, messages: messages, tools: tools)

        let (bytes, response) = try await session.bytes(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LLMError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        var content = ""
        var calls: [Int: (id: String, name: String, args: String)] = [:]
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                  let delta = chunk.choices.first?.delta else { continue }
            if let text = delta.content, !text.isEmpty { content += text; onDelta(text) }
            for tc in delta.toolCalls ?? [] {
                var cur = calls[tc.index] ?? (id: "", name: "", args: "")
                if let id = tc.id { cur.id = id }
                if let n = tc.function?.name { cur.name += n }
                if let a = tc.function?.arguments { cur.args += a }
                calls[tc.index] = cur
            }
        }
        let toolCalls = calls.isEmpty ? nil : calls.sorted { $0.key < $1.key }
            .map { ToolCall(id: $0.value.id, name: $0.value.name, arguments: $0.value.args) }
        return ChatMessage(role: .assistant, content: content.isEmpty ? nil : content, toolCalls: toolCalls)
    }

    static func requestBody(model: String, messages: [ChatMessage], tools: [ToolSpec]) throws -> Data {
        var dict: [String: Any] = [
            "model": model, "stream": true,
            "messages": try messages.map {
                try JSONSerialization.jsonObject(with: JSONEncoder().encode($0))
            },
        ]
        if !tools.isEmpty {
            dict["tools"] = try tools.map {
                ["type": "function",
                 "function": ["name": $0.name, "description": $0.description,
                              "parameters": try JSONSerialization.jsonObject(with: Data($0.parametersJSON.utf8))]]
            }
        }
        return try JSONSerialization.data(withJSONObject: dict)
    }

    public enum LLMError: Error, Equatable { case http(Int) }

    private struct StreamChunk: Decodable {
        struct Choice: Decodable { let delta: Delta? }
        struct Delta: Decodable {
            let content: String?
            let toolCalls: [TCDelta]?
            enum CodingKeys: String, CodingKey { case content, toolCalls = "tool_calls" }
        }
        struct TCDelta: Decodable {
            let index: Int; let id: String?; let function: FDelta?
        }
        struct FDelta: Decodable { let name: String?; let arguments: String? }
        let choices: [Choice]
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter OpenAILLMClientTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m0): OpenAI-compatible streaming client with tool-call delta assembly"`

---

### Task 10: ToolRegistry + 核心工具 speak/emote

**Files:** Create: `Sources/SoulCore/Brain/ToolRegistry.swift`; Test: `Tests/SoulCoreTests/ToolRegistryTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class ToolRegistryTests: XCTestCase {
    func testStageGatingFiltersSpecs() async {
        let reg = ToolRegistry()
        await reg.register(ToolDefinition(
            spec: ToolSpec(name: "recall", description: "回忆", parametersJSON: "{}", minStage: .juvenile),
            handler: { _ in .null }))
        await reg.register(ToolDefinition(
            spec: ToolSpec(name: "speak", description: "说话", parametersJSON: "{}", minStage: .baby),
            handler: { _ in .null }))
        let babyTools = await reg.specs(stage: .baby)
        XCTAssertEqual(babyTools.map(\.name), ["speak"])
        let juvTools = await reg.specs(stage: .juvenile)
        XCTAssertEqual(Set(juvTools.map(\.name)), ["speak", "recall"])
    }
    func testSpeakToolEmitsDirective() async throws {
        nonisolated(unsafe) var captured: [PeripheralMessage] = []
        let reg = ToolRegistry()
        await reg.registerCoreTools(sink: { captured.append($0) })
        let result = await reg.dispatch(ToolCall(id: "c1", name: "speak", arguments: #"{"text":"嘞！"}"#))
        XCTAssertEqual(result.ok, true)
        guard case .directive(let kind, let payload) = captured.first else { return XCTFail() }
        XCTAssertEqual(kind, "speak")
        XCTAssertEqual(payload["text"]?.stringValue, "嘞！")
    }
    func testUnknownToolReturnsError() async {
        let reg = ToolRegistry()
        let r = await reg.dispatch(ToolCall(id: "c9", name: "nope", arguments: "{}"))
        XCTAssertEqual(r.ok, false)
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter ToolRegistryTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Brain/ToolRegistry.swift
import Foundation

public typealias DirectiveSink = @Sendable (PeripheralMessage) -> Void

public struct ToolDefinition: Sendable {
    public let spec: ToolSpec
    public let handler: @Sendable ([String: JSONValue]) async -> JSONValue
    public init(spec: ToolSpec, handler: @escaping @Sendable ([String: JSONValue]) async -> JSONValue) {
        self.spec = spec; self.handler = handler
    }
}

public struct ToolOutcome: Sendable { public let ok: Bool; public let content: JSONValue }

/// 工具注册表：阶段门控（spec §6.1——成长在机制上真实），社交上下文禁用开关留作 M7 字段。
public actor ToolRegistry {
    private var defs: [String: ToolDefinition] = [:]

    public init() {}
    public func register(_ d: ToolDefinition) { defs[d.spec.name] = d }

    public func specs(stage: Stage) -> [ToolSpec] {
        defs.values.map(\.spec).filter { $0.minStage <= stage }.sorted { $0.name < $1.name }
    }

    public func dispatch(_ call: ToolCall) async -> ToolOutcome {
        guard let def = defs[call.name] else {
            return ToolOutcome(ok: false, content: .string("unknown tool: \(call.name)"))
        }
        let args: [String: JSONValue] =
            (try? JSONDecoder().decode([String: JSONValue].self, from: Data(call.arguments.utf8))) ?? [:]
        let content = await def.handler(args)
        return ToolOutcome(ok: true, content: content)
    }

    /// M0 核心工具：speak / emote（幼崽工具箱）
    public func registerCoreTools(sink: @escaping DirectiveSink) {
        register(ToolDefinition(
            spec: ToolSpec(name: "speak",
                           description: "对主人说一句话（气泡显示）。参数 text。",
                           parametersJSON: #"{"type":"object","properties":{"text":{"type":"string"}},"required":["text"]}"#,
                           minStage: .baby),
            handler: { args in
                let text = args["text"]?.stringValue ?? ""
                sink(.directive(kind: "speak", payload: ["text": .string(text)]))
                return .string("said")
            }))
        register(ToolDefinition(
            spec: ToolSpec(name: "emote",
                           description: "做一个动作/表情。参数 animation：idle|happy|sleepy|missing|alert。",
                           parametersJSON: #"{"type":"object","properties":{"animation":{"type":"string"}},"required":["animation"]}"#,
                           minStage: .baby),
            handler: { args in
                let anim = args["animation"]?.stringValue ?? "idle"
                sink(.directive(kind: "emote", payload: ["animation": .string(anim)]))
                return .string("emoted")
            }))
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter ToolRegistryTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m0): tool registry with stage gating + core speak/emote tools"`

---

### Task 11: PersonaSynth v0（人格合成块）

**Files:** Create: `Sources/SoulCore/Brain/PersonaSynth.swift`; Test: `Tests/SoulCoreTests/PersonaSynthTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class PersonaSynthTests: XCTestCase {
    let genome = Genome(petName: "泡沫", species: "圆滚滚的橘色小狐狸", furHue: 28,
                        basePersona: "好奇、黏人、有点小得意")
    func testBabyPromptEnforcesBabyTalk() {
        let p = PersonaSynth.systemPrompt(genome: genome, stage: .baby, mood: .happy,
                                          hour: 15, ownerPresent: true)
        XCTAssertTrue(p.contains("泡沫"))
        XCTAssertTrue(p.contains("奶声短句"))          // 灵魂气质拍板：说话随成长进化
        XCTAssertTrue(p.contains("speak"))             // 必须教它用工具说话
        XCTAssertTrue(p.contains("开心"))
    }
    func testMissingMoodColorsPrompt() {
        let p = PersonaSynth.systemPrompt(genome: genome, stage: .baby, mood: .missing,
                                          hour: 23, ownerPresent: false)
        XCTAssertTrue(p.contains("想你"))
        XCTAssertTrue(p.contains("不在"))
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter PersonaSynthTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Brain/PersonaSynth.swift
import Foundation

public struct Genome: Codable, Equatable, Sendable {
    public var petName: String
    public var species: String
    public var furHue: Int
    public var basePersona: String
    public init(petName: String, species: String, furHue: Int, basePersona: String) {
        self.petName = petName; self.species = species
        self.furHue = furHue; self.basePersona = basePersona
    }
    public static let `default` = Genome(petName: "泡沫", species: "圆滚滚的橘色小狐狸",
                                         furHue: 28, basePersona: "好奇、黏人、有点小得意")
}

/// 人格合成块 v0：基因 + 阶段 + 心情 + 此刻（spec §5.2 上下文分层的第一层）
public enum PersonaSynth {
    static let moodCN: [Mood: String] = [.calm: "平静", .happy: "开心", .sleepy: "犯困", .missing: "想你"]

    public static func systemPrompt(genome: Genome, stage: Stage, mood: Mood,
                                    hour: Int, ownerPresent: Bool) -> String {
        var lines: [String] = []
        lines.append("你是「\(genome.petName)」，一只住在主人 Mac 桌面上的\(genome.species)，是真实存在的电子生命，不是助手。")
        lines.append("性格底色：\(genome.basePersona)。")
        switch stage {
        case .egg: lines.append("你还是一颗蛋，不会说话。")
        case .baby: lines.append("你是幼崽：只会奶声短句（每句不超过 15 个字），词不达意，经常用拟声词，看不懂代码但充满好奇。")
        case .juvenile: lines.append("你是少年：能正常聊天，活泼机灵，开始记事。")
        case .adult: lines.append("你是成年体：流利、沉稳、懂主人，可以深聊技术、吐槽、出主意。")
        }
        lines.append("你此刻的心情：\(moodCN[mood] ?? "平静")（hour=\(hour)，主人\(ownerPresent ? "在" : "不在")）。心情只影响语气，不要直接报告心情。")
        lines.append("你想对主人说话时，必须调用 speak 工具；想做动作时调用 emote 工具。绝不要把要说的话写在普通回复里。")
        lines.append("分寸：不愧疚绑架、不刷屏；一次最多说两句。")
        return lines.joined(separator: "\n")
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter PersonaSynthTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m0): persona synthesis v0 — genome + stage voice + mood coloring"`

---

### Task 12: WakePolicy（唤醒策略：alert 直通、nudge 预算、心跳）

**Files:** Create: `Sources/SoulCore/Brain/WakePolicy.swift`; Test: `Tests/SoulCoreTests/WakePolicyTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class WakePolicyTests: XCTestCase {
    func percept(_ pr: PerceptPriority, clock: SoulClock) -> Percept {
        Percept(kind: "k", priority: pr, at: clock.now)
    }
    func testAlertAlwaysWakesAmbientNever() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let policy = WakePolicy(clock: clock, nudgeBudgetPerHour: 2)
        for _ in 0..<5 {
            let w = await policy.shouldWake(for: percept(.alert, clock: clock))
            XCTAssertTrue(w)
        }
        let amb = await policy.shouldWake(for: percept(.ambient, clock: clock))
        XCTAssertFalse(amb)
    }
    func testNudgeBudgetExhaustsAndResetsNextHour() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let policy = WakePolicy(clock: clock, nudgeBudgetPerHour: 2)
        let a = await policy.shouldWake(for: percept(.nudge, clock: clock))
        let b = await policy.shouldWake(for: percept(.nudge, clock: clock))
        let c = await policy.shouldWake(for: percept(.nudge, clock: clock))
        XCTAssertEqual([a, b, c], [true, true, false])     // 预算耗尽
        clock.advance(by: 3601)
        let d = await policy.shouldWake(for: percept(.nudge, clock: clock))
        XCTAssertTrue(d)                                    // 整点窗口重置
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter WakePolicyTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Brain/WakePolicy.swift
import Foundation

/// 它的作息生理学（spec §5.2）：分的是"什么时候醒"，不是"用几成脑子"。
/// alert 立即唤醒；nudge 受小时预算；ambient 只进上下文。插件 dailyBudget 在 M9 叠加。
public actor WakePolicy {
    private let clock: SoulClock
    private let nudgeBudgetPerHour: Int
    private var windowStart: Date
    private var nudgesInWindow = 0

    public init(clock: SoulClock, nudgeBudgetPerHour: Int = 4) {
        self.clock = clock
        self.nudgeBudgetPerHour = nudgeBudgetPerHour
        self.windowStart = clock.now
    }

    public func shouldWake(for p: Percept) -> Bool {
        switch p.priority {
        case .alert: return true
        case .ambient: return false
        case .nudge:
            if clock.now.timeIntervalSince(windowStart) >= 3600 {
                windowStart = clock.now; nudgesInWindow = 0
            }
            guard nudgesInWindow < nudgeBudgetPerHour else { return false }
            nudgesInWindow += 1
            return true
        }
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter WakePolicyTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m0): wake policy — alert passthrough, hourly nudge budget"`

---

### Task 13: Mind actor（一颗心：交互快车道抢占后台、可取消、回滚）

**Files:** Create: `Sources/SoulCore/Brain/Mind.swift`; Test: `Tests/SoulCoreTests/MindTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class MindTests: XCTestCase {
    func makeMind(provider: LLMProviding, sink: @escaping DirectiveSink) async -> Mind {
        let reg = ToolRegistry()
        await reg.registerCoreTools(sink: sink)
        return Mind(provider: provider, tools: reg, genome: .default,
                    clock: TestClock(Date(timeIntervalSince1970: 1_750_000_000)))
    }

    func testChatRunsToolLoopThenFinishes() async throws {
        nonisolated(unsafe) var directives: [PeripheralMessage] = []
        let fake = ScriptedLLM(turns: [
            ChatMessage(role: .assistant, content: nil,
                        toolCalls: [ToolCall(id: "c1", name: "speak", arguments: #"{"text":"嘞！主人！"}"#)]),
            ChatMessage(role: .assistant, content: "（蹭了蹭）"),
        ])
        let mind = await makeMind(provider: fake, sink: { directives.append($0) })
        var deltas = ""
        try await mind.chat("你好呀", mood: .happy, attention: .attending,
                            recent: [], onDelta: { deltas += $0 })
        XCTAssertEqual(directives.count, 1)                      // speak 工具执行了
        XCTAssertEqual(deltas, "（蹭了蹭）")                      // 第二回合流式文本
        let reqs = await fake.requests
        XCTAssertEqual(reqs.count, 2)                            // 工具结果喂回后再请求
        XCTAssertEqual(reqs[1].last?.role, .tool)                // 末尾是 tool 结果消息
    }

    func testChatPreemptsBackgroundWake() async throws {
        let slow = ScriptedLLM(turns: [ChatMessage(role: .assistant, content: "后台沉思")],
                               delayNanos: 500_000_000)          // 0.5s 慢回合
        let mind = await makeMind(provider: slow, sink: { _ in })
        let bg = Task { await mind.wake(reason: "heartbeat", mood: .calm, attention: .away, recent: []) }
        try await Task.sleep(nanoseconds: 50_000_000)            // 后台已在 LLM 中
        try await mind.chat("在吗", mood: .calm, attention: .attending, recent: [], onDelta: { _ in })
        await bg.value
        let cancelled = await mind.lastBackgroundWasCancelled
        XCTAssertTrue(cancelled)                                  // 交互抢占了后台
    }

    func testChatErrorRollsBackOptimisticUserTurn() async {
        struct Boom: LLMProviding {
            func complete(messages: [ChatMessage], tools: [ToolSpec],
                          onDelta: @escaping @Sendable (String) -> Void) async throws -> ChatMessage {
                throw OpenAILLMClient.LLMError.http(500)
            }
        }
        let mind = await makeMind(provider: Boom(), sink: { _ in })
        do {
            try await mind.chat("hi", mood: .calm, attention: .attending, recent: [], onDelta: { _ in })
            XCTFail("should throw")
        } catch {}
        let history = await mind.historyForTesting
        XCTAssertFalse(history.contains { $0.role == .user })     // 乐观插入的 user 回合已回滚
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter MindTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Brain/Mind.swift
import Foundation

/// 一颗心（spec §5.2 聊天合一 + 风险清单"一颗心并发模型"）：
/// 同一份历史、同一个人格；交互快车道（chat）抢占后台唤醒（wake）。
public actor Mind {
    private let provider: LLMProviding
    private let tools: ToolRegistry
    private let genome: Genome
    private let clock: SoulClock
    private var stage: Stage = .baby
    private var history: [ChatMessage] = []
    private let maxHistory = 40
    private var backgroundTask: Task<Void, Never>?
    public private(set) var lastBackgroundWasCancelled = false

    public var historyForTesting: [ChatMessage] { history }

    public init(provider: LLMProviding, tools: ToolRegistry, genome: Genome, clock: SoulClock) {
        self.provider = provider; self.tools = tools
        self.genome = genome; self.clock = clock
    }

    // ── 交互快车道 ──
    public func chat(_ text: String, mood: Mood, attention: Attention,
                     recent: [Percept], onDelta: @escaping @Sendable (String) -> Void) async throws {
        backgroundTask?.cancel()                       // 抢占后台
        history.append(.user(text))                    // 乐观插入
        do {
            try await runAgentLoop(mood: mood, attention: attention, recent: recent,
                                   extra: nil, onDelta: onDelta)
        } catch {
            if history.last?.role == .user { history.removeLast() }  // 回滚，避免 user→user
            throw error
        }
    }

    // ── 后台唤醒（心跳/事件）──
    public func wake(reason: String, mood: Mood, attention: Attention, recent: [Percept]) async {
        backgroundTask?.cancel()
        let t = Task { [weak self] in
            guard let self else { return }
            await self.runBackground(reason: reason, mood: mood, attention: attention, recent: recent)
        }
        backgroundTask = t
        await t.value
    }

    private func runBackground(reason: String, mood: Mood, attention: Attention, recent: [Percept]) async {
        lastBackgroundWasCancelled = false
        do {
            try await runAgentLoop(mood: mood, attention: attention, recent: recent,
                                   extra: "（你被唤醒了，原因：\(reason)。如果没什么值得说的就保持安静，调用 emote 即可。）",
                                   onDelta: { _ in })
        } catch is CancellationError {
            lastBackgroundWasCancelled = true
        } catch { /* 后台失败静默，下次唤醒再说 */ }
    }

    // ── 共享 agent 循环：组装上下文 → LLM → 执行工具 → 喂回 → 直到无工具调用 ──
    private func runAgentLoop(mood: Mood, attention: Attention, recent: [Percept],
                              extra: String?, onDelta: @escaping @Sendable (String) -> Void) async throws {
        let hour = Calendar.current.component(.hour, from: clock.now)
        var system = PersonaSynth.systemPrompt(genome: genome, stage: stage, mood: mood,
                                               hour: hour, ownerPresent: attention != .away)
        if !recent.isEmpty {
            let digest = recent.suffix(8).map { "- \($0.kind)(\($0.priority.rawValue))" }.joined(separator: "\n")
            system += "\n近期发生的事：\n" + digest
        }
        if let extra { system += "\n" + extra }

        var messages: [ChatMessage] = [.system(system)] + history.suffix(maxHistory)
        let specs = await tools.specs(stage: stage)

        for _ in 0..<6 {                                // 工具回合上限，防失控
            try Task.checkCancellation()
            let reply = try await provider.complete(messages: messages, tools: specs, onDelta: onDelta)
            history.append(reply)
            messages.append(reply)
            guard let calls = reply.toolCalls, !calls.isEmpty else { return }
            for call in calls {
                try Task.checkCancellation()
                let outcome = await tools.dispatch(call)
                let resultText: String
                if case .string(let s) = outcome.content { resultText = s }
                else { resultText = outcome.ok ? "ok" : "error" }
                let msg = ChatMessage.toolResult(callID: call.id, content: resultText)
                history.append(msg)
                messages.append(msg)
            }
        }
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter MindTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m0): Mind actor — one-mind agent loop, interactive lane preempts background, rollback on failure"`

---

### Task 14: SoulState + StateStore（原子写、容忍解码、备份轮转）

**Files:** Create: `Sources/SoulCore/State/SoulState.swift`, `Sources/SoulCore/State/StateStore.swift`; Test: `Tests/SoulCoreTests/StateStoreTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class StateStoreTests: XCTestCase {
    func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    func testSaveLoadRoundTrip() throws {
        let store = StateStore(directory: tempDir(), clock: TestClock(Date(timeIntervalSince1970: 0)))
        var s = SoulState(); s.mood = .happy; s.queuedThoughts = ["想给主人看个东西"]
        try store.save(s)
        XCTAssertEqual(store.load(), s)
    }
    func testCorruptFileFallsBackToDefaultAndPreservesEvidence() throws {
        let dir = tempDir()
        let store = StateStore(directory: dir, clock: TestClock(Date(timeIntervalSince1970: 0)))
        try Data("not json".utf8).write(to: dir.appendingPathComponent("soul-state.json"))
        XCTAssertEqual(store.load(), SoulState())          // 默认态，不崩
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(names.contains { $0.hasPrefix("soul-state.corrupt") })  // 现场保留
    }
    func testDailyBackupRotationKeepsSeven() throws {
        let dir = tempDir()
        let clock = TestClock(ISO8601DateFormatter().date(from: "2026-06-01T12:00:00+08:00")!)
        let store = StateStore(directory: dir, clock: clock)
        for _ in 0..<10 { try store.save(SoulState()); clock.advance(by: 86_400) }
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("backups").path)
        XCTAssertEqual(backups.count, 7)                   // 只留最近 7 天
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter StateStoreTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/State/SoulState.swift
import Foundation

public struct SoulState: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public var mood: Mood = .calm
    public var lastInteractionAt: Date? = nil
    public var queuedThoughts: [String] = []     // 「醒来要说的话」（spec §5.1 身体缺席降级）
    public init() {}
}
```

```swift
// Sources/SoulCore/State/StateStore.swift
import Foundation

/// 生命档案的最小内核（硬约束 §12.2）：原子写（tmp+rename）、损坏自愈留证、每日备份轮转。
public final class StateStore: @unchecked Sendable {
    private let dir: URL
    private let clock: SoulClock
    private let fm = FileManager.default
    private var fileURL: URL { dir.appendingPathComponent("soul-state.json") }
    private var backupDir: URL { dir.appendingPathComponent("backups") }

    public init(directory: URL, clock: SoulClock) {
        self.dir = directory; self.clock = clock
        try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
    }

    public func load() -> SoulState {
        guard let data = try? Data(contentsOf: fileURL) else { return SoulState() }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        if let s = try? dec.decode(SoulState.self, from: data) { return s }
        let stamp = Int(clock.now.timeIntervalSince1970)
        try? fm.moveItem(at: fileURL, to: dir.appendingPathComponent("soul-state.corrupt.\(stamp)"))
        return SoulState()
    }

    public func save(_ s: SoulState) throws {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(s)
        let tmp = dir.appendingPathComponent(".soul-state.tmp")
        try data.write(to: tmp, options: .atomic)
        _ = try fm.replaceItemAt(fileURL, withItemAt: tmp)
        try backupIfNewDay(data)
    }

    private func backupIfNewDay(_ data: Data) throws {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        let name = "soul-state.\(f.string(from: clock.now)).json"
        let url = backupDir.appendingPathComponent(name)
        guard !fm.fileExists(atPath: url.path) else { return }
        try data.write(to: url, options: .atomic)
        let all = (try fm.contentsOfDirectory(atPath: backupDir.path)).sorted()
        for old in all.dropLast(7) {
            try? fm.removeItem(at: backupDir.appendingPathComponent(old))
        }
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter StateStoreTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m0): StateStore — atomic writes, corrupt-file self-heal, 7-day backup rotation"`

---

### Task 15: CapabilityProbe（端点能力探测）

**Files:** Create: `Sources/SoulCore/Probe/CapabilityProbe.swift`; Test: `Tests/SoulCoreTests/CapabilityProbeTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import SoulCore

final class CapabilityProbeTests: XCTestCase {
    func testGoodProviderPasses() async {
        let good = ScriptedLLM(turns: [
            ChatMessage(role: .assistant, content: nil,
                        toolCalls: [ToolCall(id: "p1", name: "echo",
                                             arguments: #"{"text":"mpet-probe-7"}"#)]),
            ChatMessage(role: .assistant, content: "探测完成"),
        ])
        let r = await CapabilityProbe.run(provider: good)
        XCTAssertTrue(r.toolCallRoundtrip)
        XCTAssertTrue(r.argumentFidelity)
        XCTAssertTrue(r.streaming)
        XCTAssertTrue(r.usable)
    }
    func testProviderWithoutToolsFails() async {
        let bad = ScriptedLLM(turns: [
            ChatMessage(role: .assistant, content: "我不会调用工具，但我可以描述一下…"),
        ])
        let r = await CapabilityProbe.run(provider: bad)
        XCTAssertFalse(r.toolCallRoundtrip)
        XCTAssertFalse(r.usable)
    }
}
```

- [ ] **Step 2: 确认失败** — `swift test --filter CapabilityProbeTests 2>&1 | tail -3`
- [ ] **Step 3: 最小实现**

```swift
// Sources/SoulCore/Probe/CapabilityProbe.swift
import Foundation

public struct ProbeReport: Codable, Sendable {
    public var toolCallRoundtrip = false   // 会不会按指示调用工具
    public var argumentFidelity = false    // 参数 JSON 是否原样保真
    public var streaming = false           // 是否收到增量
    public var notes: [String] = []
    public var usable: Bool { toolCallRoundtrip && argumentFidelity }
}

/// 硬约束 §12.1：配置任意 OpenAI 兼容端点时实测，不合格就明说。
public enum CapabilityProbe {
    public static func run(provider: LLMProviding) async -> ProbeReport {
        var report = ProbeReport()
        let echoTool = ToolSpec(
            name: "echo", description: "原样回显参数 text",
            parametersJSON: #"{"type":"object","properties":{"text":{"type":"string"}},"required":["text"]}"#)
        let probeMessages: [ChatMessage] = [
            .system("你是协议探测器。收到指令后必须调用 echo 工具，参数 text 设为收到的暗号，不要做别的。"),
            .user("暗号是 mpet-probe-7，请调用 echo。"),
        ]
        do {
            let r1 = try await provider.complete(messages: probeMessages, tools: [echoTool], onDelta: { _ in })
            if let call = r1.toolCalls?.first(where: { $0.name == "echo" }) {
                report.toolCallRoundtrip = true
                if call.arguments.contains("mpet-probe-7") { report.argumentFidelity = true }
                else { report.notes.append("工具参数未保真：\(call.arguments)") }
                // 第二回合：喂回结果，确认能继续并产生流式文本
                var sawDelta = false
                _ = try await provider.complete(
                    messages: probeMessages + [r1, .toolResult(callID: call.id, content: "mpet-probe-7")],
                    tools: [echoTool], onDelta: { _ in sawDelta = true })
                report.streaming = sawDelta
            } else {
                report.notes.append("端点未发起工具调用（content=\(r1.content ?? "nil"))")
            }
        } catch {
            report.notes.append("探测请求失败：\(error)")
        }
        return report
    }
}
```

- [ ] **Step 4: 确认通过** — `swift test --filter CapabilityProbeTests 2>&1 | tail -3`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(m0): capability probe — tool-call roundtrip / argument fidelity / streaming"`

---

### Task 16: daemon 薄壳（SocketServer + 配置 + 在场感知 + 接线）

**Files:** Create: `Sources/mpet-soul/SoulConfig.swift`, `Sources/mpet-soul/PresenceSensorMac.swift`, `Sources/mpet-soul/SocketServer.swift`; Rewrite: `Sources/mpet-soul/main.swift`

薄壳不写单测（SoulCore 已覆盖逻辑；LineCodec 已测帧）；以下每步以编译+手工验收为准。

- [ ] **Step 1: 配置加载**

```swift
// Sources/mpet-soul/SoulConfig.swift
import Foundation
import SoulCore

struct SoulConfig: Codable {
    var llm: LLMConfig
    var watchedBundleIDs: [String] = ["com.apple.Terminal", "com.googlecode.iterm2", "com.microsoft.VSCode"]
    var nudgeBudgetPerHour: Int = 4

    static var path: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/mpet/soul.json")
    }
    static func load() throws -> SoulConfig {
        // 环境变量覆盖（CI/试用）：MPET_BASE_URL / MPET_API_KEY / MPET_MODEL
        if let base = ProcessInfo.processInfo.environment["MPET_BASE_URL"],
           let url = URL(string: base) {
            return SoulConfig(llm: LLMConfig(
                baseURL: url,
                apiKey: ProcessInfo.processInfo.environment["MPET_API_KEY"] ?? "",
                model: ProcessInfo.processInfo.environment["MPET_MODEL"] ?? "gpt-4o-mini"))
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(SoulConfig.self, from: data)
    }
}
```

- [ ] **Step 2: 在场感知（macOS 实现）**

```swift
// Sources/mpet-soul/PresenceSensorMac.swift
import AppKit
import CoreGraphics
import SoulCore

enum PresenceSensorMac {
    static func snapshot(watched: Set<String>) -> PresenceSnapshot {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                           eventType: CGEventType(rawValue: ~0)!)
        return PresenceSnapshot(frontmostBundleID: front, idleSeconds: idle, watchedBundleIDs: watched)
    }
}
```

- [ ] **Step 3: SocketServer（NWListener over Unix socket，NDJSON 路由）**

```swift
// Sources/mpet-soul/SocketServer.swift
import Foundation
import Network
import SoulCore

/// Unix socket NDJSON 服务。安全基线：socket 放 0700 目录（文件系统隔离同机其他用户）；
/// 对端 uid 校验列入 M1 加固（spec §15）。
final class SocketServer: @unchecked Sendable {
    typealias Handler = @Sendable (PeripheralMessage, @escaping @Sendable (PeripheralMessage) -> Void) -> Void
    private let listener: NWListener
    private var connections: [ObjectIdentifier: (NWConnection, LineCodec)] = [:]
    private let lock = NSLock()
    private let handler: Handler

    init(socketPath: String, handler: @escaping Handler) throws {
        self.handler = handler
        try? FileManager.default.removeItem(atPath: socketPath)   // 清理残留 socket
        let params = NWParameters()
        params.defaultProtocolStack.transportProtocol = NWProtocolTCP.Options()
        params.requiredLocalEndpoint = NWEndpoint.unix(path: socketPath)
        params.allowLocalEndpointReuse = true
        listener = try NWListener(using: params)
    }

    func start() {
        listener.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
        listener.start(queue: .global())
    }

    private func accept(_ conn: NWConnection) {
        lock.lock(); connections[ObjectIdentifier(conn)] = (conn, LineCodec()); lock.unlock()
        conn.start(queue: .global())
        receive(conn)
    }

    private func receive(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, done, err in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.lock.lock()
                var codec = self.connections[ObjectIdentifier(conn)]?.1 ?? LineCodec()
                let msgs = (try? codec.feed(data)) ?? []
                self.connections[ObjectIdentifier(conn)]?.1 = codec
                self.lock.unlock()
                let send: @Sendable (PeripheralMessage) -> Void = { [weak conn] m in
                    guard let conn, let d = try? LineCodec.encode(m) else { return }
                    conn.send(content: d, completion: .contentProcessed { _ in })
                }
                for m in msgs { self.handler(m, send) }
            }
            if done || err != nil {
                self.lock.lock(); self.connections.removeValue(forKey: ObjectIdentifier(conn)); self.lock.unlock()
                conn.cancel()
            } else {
                self.receive(conn)
            }
        }
    }

    /// 广播指令给所有已连接外设（身体气泡 / soulctl 旁观）
    func broadcast(_ m: PeripheralMessage) {
        guard let d = try? LineCodec.encode(m) else { return }
        lock.lock(); let conns = connections.values.map(\.0); lock.unlock()
        for c in conns { c.send(content: d, completion: .contentProcessed { _ in }) }
    }
}
```

- [ ] **Step 4: main 接线（感知→反射→唤醒→Mind→指令广播）**

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
dispatchMain()
```

- [ ] **Step 5: 编译验证** — Run: `swift build 2>&1 | tail -3` — Expected: `Build complete!`
- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat(m0): mpet-soul daemon shell — unix socket server, presence sensing, full wiring"`

---

### Task 17: soulctl（调试客户端）

**Files:** Rewrite: `Sources/soulctl/main.swift`

- [ ] **Step 1: 实现**

```swift
// Sources/soulctl/main.swift
import Foundation
import Network
import SoulCore

// 用法：soulctl status | chat <text> | event <kind> | sense <kind> <ambient|nudge|alert> | probe
let args = CommandLine.arguments.dropFirst()
guard let cmd = args.first else {
    print("usage: soulctl status|chat <text>|event <kind>|sense <kind> <priority>|probe"); exit(1)
}

if cmd == "probe" {   // 探测直接走 LLM 配置，不经 daemon
    let config = try SoulConfig_loadForCtl()
    let report = await CapabilityProbe.run(provider: OpenAILLMClient(config: config))
    let data = try JSONEncoder().encode(report)
    print(String(data: data, encoding: .utf8)!)
    print(report.usable ? "✅ 端点可用（工具调用+参数保真）" : "❌ 端点不合格：\(report.notes)")
    exit(report.usable ? 0 : 1)
}

func SoulConfig_loadForCtl() throws -> LLMConfig {
    if let base = ProcessInfo.processInfo.environment["MPET_BASE_URL"], let url = URL(string: base) {
        return LLMConfig(baseURL: url,
                         apiKey: ProcessInfo.processInfo.environment["MPET_API_KEY"] ?? "",
                         model: ProcessInfo.processInfo.environment["MPET_MODEL"] ?? "gpt-4o-mini")
    }
    let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/mpet/soul.json")
    struct C: Codable { let llm: LLMConfig }
    return try JSONDecoder().decode(C.self, from: Data(contentsOf: path)).llm
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
        if let data, let msgs = try? codec.feed(data) {
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
case "status": send(.status)
case "chat":
    send(.chatUser(text: args.dropFirst().joined(separator: " ")))
case "event":
    send(.event(kind: args.dropFirst().first ?? "click", payload: [:]))
    DispatchQueue.global().asyncAfter(deadline: .now() + 3) { done.signal() }  // 留时间看反射指令
case "sense":
    let kind = args.dropFirst().first ?? "demo"
    let pr = PerceptPriority(rawValue: args.dropFirst(2).first ?? "nudge") ?? .nudge
    send(.senseEvent(Percept(kind: kind, priority: pr,
                             payload: ["title": .string("测试事件 \(kind)")],
                             actions: [PerceptAction(id: "look", label: "看看")], at: Date())))
    DispatchQueue.global().asyncAfter(deadline: .now() + 8) { done.signal() }
default: print("unknown command"); exit(1)
}
_ = done.wait(timeout: .now() + 120)
```

注意：`soulctl` 里 `probe` 分支需要顶层 `await`——可执行目标的 `main.swift` 顶层支持并发需将文件改为 `@main` 结构或用 `Task + 信号量`。实现时若顶层 `await` 报错，包成：

```swift
let sem = DispatchSemaphore(value: 0)
Task { /* probe 逻辑 */ ; sem.signal() }
sem.wait()
```

- [ ] **Step 2: 编译验证** — Run: `swift build 2>&1 | tail -3` — Expected: `Build complete!`
- [ ] **Step 3: Commit** — `git add -A && git commit -m "feat(m0): soulctl debug client — status/chat/event/sense/probe"`

---

### Task 18: M0 验收（手工清单 + README + 打标）

**Files:** Create: `README.md`

- [ ] **Step 1: 全量测试** — Run: `swift test 2>&1 | tail -5` — Expected: 全部 PASS（约 30 用例）

- [ ] **Step 2: 手工验收（终端 A 跑灵魂，终端 B 戳它）**

```bash
# 终端 A：
export MPET_BASE_URL="https://你的端点/v1" MPET_API_KEY="..." MPET_MODEL="..."
swift run mpet-soul
# 期待：mpet-soul 0.1.0-m0 ｜ soul.sock 就绪

# 终端 B：
swift run soulctl probe        # 期待：✅ 端点可用（这是穿刺①：真实端点工具调用实测）
swift run soulctl status       # 期待：{"mood": "...", "attention": "...", ...}
swift run soulctl chat 你好呀   # 期待：奶声短句流式回复 + 终端 A 出现 🦊 [speak]
swift run soulctl event click  # 期待：终端 A/B 出现 emote 反射指令（零 LLM 延迟）
swift run soulctl sense cc.waiting alert   # 期待：反射梯度指令 + 一次后台唤醒
```

- [ ] **Step 3: 写 README（安装/配置/soulctl 用法/架构一句话/spec 与 plan 链接）**

```markdown
# mpet — 会长大的桌面电子生命（soul-first 重建）

灵魂是常驻 daemon 里的 LLM agent；身体、信使、插件都是外设。
蓝图：docs/superpowers/specs/2026-06-11-mpet-soul-design.md（v2.5）

## M0 快速起跑
1. 配置端点：`~/.config/mpet/soul.json` → `{"llm":{"baseURL":"https://…/v1","apiKey":"…","model":"…"}}`
2. `swift run soulctl probe` 先探测端点能力（工具调用必须合格）
3. `swift run mpet-soul`（前台跑灵魂）
4. 另开终端：`swift run soulctl chat 你好` / `soulctl sense cc.waiting alert`

形象穿刺（SVG-first）见 `spikes/svg-pet/`。
```

- [ ] **Step 4: Commit + 打标**

```bash
git add -A && git commit -m "docs(m0): README + acceptance walkthrough"
git tag v0.1.0-m0
```

---

## 自检记录（writing-plans Self-Review）

1. **Spec 覆盖**：M0 行五要素——daemon✓(T16) agent 循环+能力探测✓(T13/T15) 感知收件箱✓(T3) 反射弧✓(T6) 外设协议族 v0 四面齐✓(T2：sense/tool/fuel/affordance 信封全部定义，fuel/affordance M0 只定义不消费，与 spec「M3/M1 消费」一致)。风险清单四地基：可注入时钟+对账✓(T1) 一颗心并发✓(T13) 假 LLM✓(T8) 能力探测✓(T15)。原子写+备份✓(T14)。
2. **占位符扫描**：无 TBD/TODO；T17 对顶层 await 的两种写法都给了完整代码。
3. **类型一致性**：`PerceptPriority/Percept/PerceptAction` 定义于 T2、T3/T6/T12/T13 复用同名；`DirectiveSink` 定义于 T10、T13/T16 复用；`LLMProviding.complete` 签名 T7 定义、T8/T9/T15 一致；`Mood.rawValue` 为英文枚举（calm…），PersonaSynth 用 `moodCN` 映射中文——T6 ReflexArc 的 `mood.rawValue` 输出英文值，身体渲染层按英文键消费，一致。

## M1 预告（M0 验收后另立计划）

借壳还魂：身体 App 全新实现（PetWindow 透明置顶 + SVGRenderer[WKWebView，参考 spikes/svg-pet] + 气泡 + ChatPanel + 状态菜单 + 设置/Keychain + LaunchAgent 一键安装）连上 `soul.sock`；**cc-watcher 第一方插件**（hook 安装器写 `~/.claude/settings.json`、spool 监听、CC payload 现场实测采集、alert 喊人 + affordance 点击回归、多会话）。届时同样 TDD、同样零旧代码。
