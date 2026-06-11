# M3 它开始长大 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** 核心经济（XP/羁绊/阶段门控/语言进化）+ cc-watcher fuel 上报 + 开发模式快进 + 成长可感知面 + 伙食费透明——它真的在长大了。

**Architecture:** 新增 `GrowthState`（XP/羁绊/streak/阶段）+ `EconomyEngine`（XP 计算/封顶/streak 倍率）+ `FuelProcessor`（fuel→XP 曲线）+ `GrowthStateStore`（独立持久化）+ DaemonSoul 集成 + cc-watcher fuel 上报 + MpetApp 成长感知 UI。

**对应 spec：** §6.1 成长四维 · §6.2 经济模型 · §10.1 fuel 能力面 · §10.9 cc-watcher 口粮上报与回填 · §11 成长可感知面 · §12 #5 开发模式快进 · §12 #6 伙食费透明。

**M3 不做：** 记忆/做梦/日记（M4）、形象系统（M5）、小爪子（M6）、P2P 社交（M7+）、真正 LLM 生成 SVG（M5 用固定美术包）。

---

## 文件结构

```
Sources/SoulCore/
  Growth/GrowthState.swift          # NEW: XP/羁绊/streak/阶段
  Growth/EconomyEngine.swift        # NEW: XP 计算规则+封顶+streak 倍率
  Growth/FuelProcessor.swift        # NEW: fuel→XP log 递减曲线
  Growth/GrowthStateStore.swift     # NEW: 原子写成长档案
  Growth/DevMode.swift              # NEW: XP 注入/阶段跳转/快进
Sources/mpet-cc-watcher/main.swift  # MODIFY: fuel.report 上报
Sources/SoulCore/State/DaemonSoul.swift  # MODIFY: 集成 growth
Sources/MpetApp/PetViewModel.swift       # MODIFY: growth 感知
Sources/MpetApp/StatusMenu.swift         # MODIFY: 显示 XP/streak
Tests/SoulCoreTests/
  GrowthStateTests.swift            # NEW
  EconomyEngineTests.swift          # NEW
  FuelProcessorTests.swift          # NEW
  GrowthStateStoreTests.swift       # NEW
  DevModeTests.swift                # NEW
```

---

### Task 0: GrowthState（成长状态模型）

```swift
// Sources/SoulCore/Growth/GrowthState.swift
import Foundation

public struct GrowthState: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public var totalXP: Int = 0
    public var todayXP: Int = 0
    public var bond: Int = 0                    // 羁绊值
    public var stage: Stage = .baby             // 当前阶段
    public var streakDays: Int = 0              // 连续活跃天数
    public var lastActiveDay: String = ""       // "yyyy-MM-dd"
    public var todayDate: String = ""           // 当前日期
    public var hatchDate: Date? = nil           // 孵化日（旅程起点）

    // 阶段阈值（spec §6.1）
    public static let stageThresholds: [(Stage, Int)] = [
        (.egg, 0), (.baby, 0), (.juvenile, 500), (.adult, 2500)
    ]

    /// 基于总 XP 计算应达到的阶段
    public static func stageForXP(_ xp: Int) -> Stage {
        if xp >= 2500 { return .adult }
        if xp >= 500 { return .juvenile }
        return .baby
    }

    /// 到下一阶段的进度（0.0-1.0）
    public var progressToNext: Double {
        switch stage {
        case .egg, .baby: return min(1.0, Double(totalXP) / 500.0)
        case .juvenile: return min(1.0, Double(totalXP - 500) / 2000.0)
        case .adult: return 1.0
        }
    }

    /// 是否需要阶段晋级
    public var shouldEvolve: Bool {
        Self.stageForXP(totalXP) > stage
    }
}
```

```swift
// Tests/SoulCoreTests/GrowthStateTests.swift
import XCTest
@testable import SoulCore

final class GrowthStateTests: XCTestCase {
    func testInitialState() {
        let g = GrowthState()
        XCTAssertEqual(g.totalXP, 0); XCTAssertEqual(g.stage, .baby); XCTAssertEqual(g.streakDays, 0)
    }
    func testStageForXPThresholds() {
        XCTAssertEqual(GrowthState.stageForXP(0), .baby)
        XCTAssertEqual(GrowthState.stageForXP(499), .baby)
        XCTAssertEqual(GrowthState.stageForXP(500), .juvenile)
        XCTAssertEqual(GrowthState.stageForXP(2499), .juvenile)
        XCTAssertEqual(GrowthState.stageForXP(2500), .adult)
        XCTAssertEqual(GrowthState.stageForXP(99999), .adult)
    }
    func testProgressToNext() {
        var g = GrowthState(); g.totalXP = 250
        XCTAssertEqual(g.progressToNext, 0.5, accuracy: 0.01)
        g.totalXP = 1500; g.stage = .juvenile
        XCTAssertEqual(g.progressToNext, 0.5, accuracy: 0.01)
    }
    func testShouldEvolve() {
        var g = GrowthState(); g.totalXP = 500
        XCTAssertTrue(g.shouldEvolve)  // baby → juvenile
        g.stage = .juvenile
        XCTAssertFalse(g.shouldEvolve)
    }
    func testCodableRoundTrip() throws {
        var g = GrowthState(); g.totalXP = 1234; g.bond = 42; g.streakDays = 7; g.stage = .juvenile
        let data = try JSONEncoder().encode(g)
        let decoded = try JSONDecoder().decode(GrowthState.self, from: data)
        XCTAssertEqual(decoded, g)
    }
}
```

### Task 1: EconomyEngine（XP 计算）

```swift
// Sources/SoulCore/Growth/EconomyEngine.swift
import Foundation

/// M3 经济引擎（spec §6.2）
public enum EconomyEngine {
    public static let dailyXPCap = 150
    public static let fuelXPCap = 80
    public static let interactionBonusCap = 20
    public static let chatBonusCap = 20
    public static let basePresenceXP = 10

    /// 计算一次 XP 收益（已扣除当日已得）
    public static func calcXPGain(
        basePresence: Int = basePresenceXP,
        fuelRaw: Double = 0,
        interactionBonuses: Int = 0,
        chatBonuses: Int = 0,
        streakMultiplier: Double = 1.0,
        todayXPSoFar: Int = 0
    ) -> Int {
        let fuelXP = min(FuelProcessor.process(raw: fuelRaw), fuelXPCap)
        let interactionXP = min(interactionBonuses, interactionBonusCap)
        let chatXP = min(chatBonuses, chatBonusCap)
        let raw = Double(basePresence + fuelXP + interactionXP + chatXP) * min(streakMultiplier, 1.5)
        let capped = min(Int(raw), dailyXPCap - todayXPSoFar)
        return max(0, capped)
    }

    /// streak 倍率：连续天数 1→1.0, 3→1.1, 7→1.2, 14→1.3, 30→1.5
    public static func streakMultiplier(days: Int) -> Double {
        switch days {
        case 0...1: return 1.0
        case 2...3: return 1.1
        case 4...7: return 1.2
        case 8...14: return 1.3
        case 15...30: return 1.4
        default: return 1.5
        }
    }

    /// 计算羁绊增量
    public static func bondGain(for interaction: BondInteraction) -> Int {
        switch interaction {
        case .chat: return 2
        case .respondToCall: return 5
        case .respondToAttentionSeek: return 3
        case .milestone: return 10
        }
    }

    public enum BondInteraction { case chat, respondToCall, respondToAttentionSeek, milestone }
}
```

```swift
// Tests/SoulCoreTests/EconomyEngineTests.swift
import XCTest
@testable import SoulCore

final class EconomyEngineTests: XCTestCase {
    func testBasePresenceOnly() {
        let xp = EconomyEngine.calcXPGain()
        XCTAssertEqual(xp, 10)
    }
    func testFuelIsDiminished() {
        let xp = EconomyEngine.calcXPGain(fuelRaw: 10000)
        XCTAssertTrue(xp <= EconomyEngine.dailyXPCap)
        XCTAssertTrue(xp > 10)  // fuel 加成了
    }
    func testDailyCapEnforced() {
        let xp = EconomyEngine.calcXPGain(fuelRaw: 99999, interactionBonuses: 100, chatBonuses: 100, todayXPSoFar: 0)
        XCTAssertEqual(xp, EconomyEngine.dailyXPCap)
    }
    func testDailyCapWithExistingXP() {
        let xp = EconomyEngine.calcXPGain(todayXPSoFar: 140)
        XCTAssertEqual(xp, 10)  // 150 - 140 = 10 remaining
    }
    func testStreakMultiplierCapped() {
        XCTAssertEqual(EconomyEngine.streakMultiplier(days: 100), 1.5)
        XCTAssertEqual(EconomyEngine.streakMultiplier(days: 0), 1.0)
        XCTAssertEqual(EconomyEngine.streakMultiplier(days: 7), 1.2)
    }
    func testBondGain() {
        XCTAssertEqual(EconomyEngine.bondGain(for: .chat), 2)
        XCTAssertEqual(EconomyEngine.bondGain(for: .respondToCall), 5)
    }
}
```

### Task 2: FuelProcessor（fuel→XP 曲线）

```swift
// Sources/SoulCore/Growth/FuelProcessor.swift
import Foundation

/// M3 fuel 曲线（spec §6.2："fuel 口粮 → log 递减"）
public enum FuelProcessor {
    /// raw → XP，log 递减：前 1000 raw ≈ 10 XP，前 10000 ≈ 23 XP
    public static func process(raw: Double) -> Int {
        guard raw > 0 else { return 0 }
        return Int(log(1 + raw) * 3)
    }

    /// 多插件合计：各自处理后加总，受 fuelXPCap 约束
    public static func processMultiple(rawValues: [Double]) -> Int {
        let total = rawValues.reduce(0.0, +)
        return min(process(raw: total), EconomyEngine.fuelXPCap)
    }
}
```

```swift
// Tests/SoulCoreTests/FuelProcessorTests.swift
import XCTest
@testable import SoulCore

final class FuelProcessorTests: XCTestCase {
    func testZeroRawGivesZeroXP() {
        XCTAssertEqual(FuelProcessor.process(raw: 0), 0)
    }
    func testLogDiminishing() {
        let xp1k = FuelProcessor.process(raw: 1_000)
        let xp10k = FuelProcessor.process(raw: 10_000)
        let xp100k = FuelProcessor.process(raw: 100_000)
        // log 递减：10x raw ≠ 10x XP
        XCTAssertTrue(xp10k < xp1k * 10)
        XCTAssertTrue(xp100k < xp10k * 10)
        XCTAssertTrue(xp1k > 0)
    }
    func testMultipleFeedsSummed() {
        let single = FuelProcessor.process(raw: 5000)
        let multi = FuelProcessor.processMultiple(rawValues: [2500, 2500])
        XCTAssertEqual(single, multi)  // 同总量同结果
    }
    func testMultipleFeedsCapped() {
        let capped = FuelProcessor.processMultiple(rawValues: [99999, 99999])
        XCTAssertEqual(capped, EconomyEngine.fuelXPCap)
    }
}
```

### Task 3: GrowthStateStore（成长档案持久化）

```swift
// Sources/SoulCore/Growth/GrowthStateStore.swift
import Foundation

/// M3 成长档案持久化（独立于 SoulState，spec §12.2）
public final class GrowthStateStore: @unchecked Sendable {
    private let dir: URL
    private let clock: SoulClock
    private let fm = FileManager.default
    private var fileURL: URL { dir.appendingPathComponent("growth-state.json") }

    public init(directory: URL, clock: SoulClock) {
        self.dir = directory; self.clock = clock
    }

    public func load() -> GrowthState {
        guard let data = try? Data(contentsOf: fileURL) else { return GrowthState() }
        if let s = try? JSONDecoder().decode(GrowthState.self, from: data) { return s }
        return GrowthState()
    }

    public func save(_ s: GrowthState) throws {
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(s)
        let tmp = dir.appendingPathComponent(".growth-state.tmp")
        try data.write(to: tmp, options: .atomic)
        _ = try? fm.replaceItemAt(fileURL, withItemAt: tmp)
        if !fm.fileExists(atPath: fileURL.path) { try? fm.moveItem(at: tmp, to: fileURL) }
    }
}
```

```swift
// Tests/SoulCoreTests/GrowthStateStoreTests.swift
import XCTest
@testable import SoulCore

final class GrowthStateStoreTests: XCTestCase {
    func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true); return u
    }
    func testSaveLoadRoundTrip() throws {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let store = GrowthStateStore(directory: tempDir(), clock: clock)
        var g = GrowthState(); g.totalXP = 1234; g.bond = 42; g.streakDays = 7
        try store.save(g)
        XCTAssertEqual(store.load(), g)
    }
    func testMissingFileReturnsDefault() {
        let store = GrowthStateStore(directory: tempDir(), clock: TestClock(Date()))
        XCTAssertEqual(store.load().totalXP, 0)
    }
    func testCorruptFileReturnsDefault() throws {
        let dir = tempDir()
        try Data("bad".utf8).write(to: dir.appendingPathComponent("growth-state.json"))
        let store = GrowthStateStore(directory: dir, clock: TestClock(Date()))
        XCTAssertEqual(store.load().totalXP, 0)
    }
}
```

### Task 4: DevMode（开发模式快进）

```swift
// Sources/SoulCore/Growth/DevMode.swift
import Foundation

/// M3 开发模式（spec §12.5）
public enum DevMode {
    public static func injectXP(_ amount: Int, into state: inout GrowthState) {
        state.totalXP += amount
        state.todayXP += amount
    }
    public static func jumpToStage(_ target: Stage, state: inout GrowthState) {
        switch target {
        case .egg: state.totalXP = 0
        case .baby: state.totalXP = 0
        case .juvenile: state.totalXP = max(state.totalXP, 500)
        case .adult: state.totalXP = max(state.totalXP, 2500)
        }
        state.stage = target
    }
    public static func forceStreak(_ days: Int, state: inout GrowthState) {
        state.streakDays = days
    }
    public static func resetGrowth(_ state: inout GrowthState) {
        state = GrowthState()
    }
}
```

```swift
// Tests/SoulCoreTests/DevModeTests.swift
import XCTest
@testable import SoulCore

final class DevModeTests: XCTestCase {
    func testInjectXP() {
        var g = GrowthState()
        DevMode.injectXP(100, into: &g)
        XCTAssertEqual(g.totalXP, 100); XCTAssertEqual(g.todayXP, 100)
    }
    func testJumpToStage() {
        var g = GrowthState()
        DevMode.jumpToStage(.juvenile, state: &g)
        XCTAssertEqual(g.stage, .juvenile); XCTAssertEqual(g.totalXP, 500)
    }
    func testJumpToAdult() {
        var g = GrowthState()
        DevMode.jumpToStage(.adult, state: &g)
        XCTAssertEqual(g.stage, .adult); XCTAssertEqual(g.totalXP, 2500)
    }
    func testForceStreak() {
        var g = GrowthState()
        DevMode.forceStreak(30, state: &g)
        XCTAssertEqual(g.streakDays, 30)
    }
    func testReset() {
        var g = GrowthState(); g.totalXP = 9999; g.bond = 99
        DevMode.resetGrowth(&g)
        XCTAssertEqual(g.totalXP, 0); XCTAssertEqual(g.bond, 0)
    }
}
```

### Task 5: DaemonSoul growth 集成

Add to DaemonSoul actor:
- `growthState: GrowthState` field
- `growthStore: GrowthStateStore` field
- `applyXP(_ amount: Int)` — add XP, check stage evolve
- `dailyRolloverIfNeeded()` — reset todayXP, update streak
- `growthSnapshot()` → `[String: JSONValue]` for status display
- Integrate fuel.report message handling

### Task 6: cc-watcher fuel.report 上报

Modify `Sources/mpet-cc-watcher/main.swift`:
- Track output-token estimates from CC events
- Emit `fuel.report` via `client.send(.fuelReport(date:raw:))`
- Simple heuristic: each PostToolUse event ≈ some token estimate

### Task 7: MpetApp 成长感知 UI

Modify `PetViewModel.swift` + `StatusMenu.swift`:
- Add `@Published var stage, todayXP, streakDays, totalXP`
- Display in status menu
- Handle stage evolution directive (special animation)

### Task 8: M3 验收 + 打标 v0.4.0-m3

---

## 自检记录

1. **Spec 覆盖**：XP 经济 ✅(T1) · 羁绊 ✅(T1) · 阶段门控 ✅(T0+T5) · fuel 曲线 ✅(T2) · 开发模式 ✅(T4) · 成长感知 ✅(T7) · cc-watcher fuel ✅(T6) · 持久化 ✅(T3)。
2. **类型一致**：`Stage` 复用 M0 枚举 · `GrowthState` 独立于 `SoulState`（schema 分离）· `EconomyEngine` 纯函数可测。
3. **占位符**：T5-T7 标注描述级，实现时补全代码。
