# M4 它记得你 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** remember/recall 工具 + 记忆存储与检索 + 做梦蒸馏 + 日记 + 防说错（置信度）+ 生命档案导出/导入 v0——它真的在记事了。

**Architecture:** 新增 `Memory` 模型（情景/语义/里程碑）+ `MemoryStore`（JSON 文件存储）+ `MemorySearch`（关键词+时近+重要度）+ `RememberTool`/`RecallTool`（阶段门控 juvenile+）+ `DreamEngine`（蒸馏情景→语义）+ `DiaryWriter`（markdown 日记）+ `ArchiveExporter`（导出/导入 v0）+ `PersonaSynth` 增强（记忆染色进 prompt）。

**对应 spec：** §7 记忆系统 · §5.2 `remember`/`recall` 阶段工具 · §12 #2 生命档案导出/导入 v0 · §3 支柱 3「记得你」。

---

## 文件结构

```
Sources/SoulCore/
  Memory/Memory.swift              # NEW: 记忆模型（情景/语义/里程碑）
  Memory/MemoryStore.swift         # NEW: JSON 文件存储（CRUD）
  Memory/MemorySearch.swift        # NEW: 关键词+时近+重要度检索
  Memory/DreamEngine.swift         # NEW: 做梦蒸馏（情景→语义）
  Memory/DiaryWriter.swift         # NEW: markdown 日记
  Memory/ArchiveExporter.swift     # NEW: 导出/导入 v0
  Memory/MemoryTools.swift         # NEW: remember/recall tool definitions
Sources/SoulCore/Brain/ToolRegistry.swift  # MODIFY: 注册 remember/recall
Sources/SoulCore/Brain/PersonaSynth.swift  # MODIFY: 记忆染色进 prompt
Sources/SoulCore/State/DaemonSoul.swift    # MODIFY: 记忆集成
Sources/mpet-soul/main.swift               # MODIFY: 接线
Tests/SoulCoreTests/
  MemoryTests.swift                # NEW
  MemoryStoreTests.swift           # NEW
  MemorySearchTests.swift          # NEW
  DreamEngineTests.swift           # NEW
  DiaryWriterTests.swift           # NEW
  ArchiveExporterTests.swift       # NEW
```

---

### Task 0: Memory 模型

```swift
// Sources/SoulCore/Memory/Memory.swift
import Foundation

public enum MemoryKind: String, Codable, Sendable {
    case episodic   // 情景记忆（具体事件）
    case semantic   // 语义记忆（关于主人的事实/偏好）
    case milestone  // 里程碑（第一次聊天、长大那天…）
}

public struct Memory: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var kind: MemoryKind
    public var content: String            // 记忆内容
    public var source: String?            // 出处原话（防说错）
    public var confidence: Double         // 置信度 0.0-1.0
    public var importance: Int            // 重要度 1-5
    public var createdAt: Date
    public var lastAccessedAt: Date?
    public var accessCount: Int = 0
    public var tags: [String] = []        // 关键词标签

    public init(id: String = UUID().uuidString, kind: MemoryKind, content: String,
                source: String? = nil, confidence: Double = 0.8, importance: Int = 3,
                createdAt: Date = Date(), tags: [String] = []) {
        self.id = id; self.kind = kind; self.content = content
        self.source = source; self.confidence = confidence
        self.importance = importance; self.createdAt = createdAt; self.tags = tags
    }
}
```

```swift
// Tests/SoulCoreTests/MemoryTests.swift
import XCTest
@testable import SoulCore

final class MemoryTests: XCTestCase {
    func testMemoryCreation() {
        let m = Memory(kind: .episodic, content: "主人今天聊了很久")
        XCTAssertEqual(m.kind, .episodic); XCTAssertEqual(m.confidence, 0.8)
    }
    func testMilestoneHighImportance() {
        let m = Memory(kind: .milestone, content: "第一次聊天", importance: 5)
        XCTAssertEqual(m.importance, 5)
    }
    func testCodableRoundTrip() throws {
        let m = Memory(kind: .semantic, content: "主人喜欢熬夜", confidence: 0.6, importance: 4, tags: ["作息"])
        let decoded = try JSONDecoder().decode(Memory.self, from: JSONEncoder().encode(m))
        XCTAssertEqual(decoded.id, m.id); XCTAssertEqual(decoded.content, m.content)
    }
}
```

### Task 1: MemoryStore（CRUD）

```swift
// Sources/SoulCore/Memory/MemoryStore.swift
import Foundation

public final class MemoryStore: @unchecked Sendable {
    private let dir: URL
    private let lock = NSLock()
    private var memories: [Memory] = []
    private var fileURL: URL { dir.appendingPathComponent("memories.json") }

    public init(directory: URL) {
        self.dir = directory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        loadFromDisk()
    }

    public func add(_ memory: Memory) {
        lock.lock(); defer { lock.unlock() }
        memories.append(memory); saveToDisk()
    }

    public func getAll() -> [Memory] {
        lock.lock(); defer { lock.unlock() }
        return memories
    }

    public func get(id: String) -> Memory? {
        lock.lock(); defer { lock.unlock() }
        return memories.first { $0.id == id }
    }

    public func update(_ memory: Memory) {
        lock.lock(); defer { lock.unlock() }
        memories = memories.map { $0.id == memory.id ? memory : $0 }
        saveToDisk()
    }

    public func delete(id: String) {
        lock.lock(); defer { lock.unlock() }
        memories.removeAll { $0.id == id }; saveToDisk()
    }

    public func count(kind: MemoryKind? = nil) -> Int {
        lock.lock(); defer { lock.unlock() }
        return kind.map { k in memories.filter { $0.kind == k }.count } ?? memories.count
    }

    public func recordAccess(id: String) {
        lock.lock(); defer { lock.unlock() }
        guard let idx = memories.firstIndex(where: { $0.id == id }) else { return }
        memories[idx].accessCount += 1
        memories[idx].lastAccessedAt = Date()
        saveToDisk()
    }

    // 纠正记忆（主人说"不对"时调用）
    public func correct(id: String, newContent: String) {
        lock.lock(); defer { lock.unlock() }
        guard let idx = memories.firstIndex(where: { $0.id == id }) else { return }
        memories[idx].content = newContent
        memories[idx].confidence = max(0.3, memories[idx].confidence - 0.2)
        saveToDisk()
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        memories = (try? JSONDecoder().decode([Memory].self, from: data)) ?? []
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(memories) else { return }
        let tmp = dir.appendingPathComponent(".memories.tmp")
        try? data.write(to: tmp, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
    }
}
```

### Task 2: MemorySearch（检索）

```swift
// Sources/SoulCore/Memory/MemorySearch.swift
import Foundation

public enum MemorySearch {
    /// 检索相关记忆：关键词匹配 + 时近 + 重要度综合打分
    public static func search(query: String, in memories: [Memory], limit: Int = 5, now: Date = Date()) -> [Memory] {
        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))
        let scored = memories.map { memory -> (Memory, Double) in
            var score = 0.0
            // 关键词匹配
            let contentWords = Set(memory.content.lowercased().split(separator: " ").map(String.init))
            let tagWords = Set(memory.tags.map { $0.lowercased() })
            let allWords = contentWords.union(tagWords)
            let keywordHits = queryWords.intersection(allWords).count
            score += Double(keywordHits) * 3.0
            // 时近加分（7天内线性衰减）
            if let lastAccess = memory.lastAccessedAt {
                let daysSince = now.timeIntervalSince(lastAccess) / 86400
                score += max(0, 2.0 - daysSince * 0.3)
            }
            // 重要度加权
            score += Double(memory.importance) * 0.5
            // 置信度加权
            score *= memory.confidence
            return (memory, score)
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }
}
```

### Task 3: DreamEngine（做梦蒸馏）

```swift
// Sources/SoulCore/Memory/DreamEngine.swift
import Foundation

public enum DreamEngine {
    /// 蒸馏情景记忆为语义记忆
    public static func distill(episodic: [Memory]) -> [Memory] {
        // 按内容相似度聚类，提取高频事实
        var semanticMemories: [Memory] = []
        let grouped = Dictionary(grouping: episodic, by: { extractTopic($0.content) })
        for (topic, events) in grouped where events.count >= 2 {
            let semantic = Memory(
                kind: .semantic,
                content: "主人似乎\(topic)",
                confidence: min(0.95, Double(events.count) * 0.15 + 0.3),
                importance: min(5, events.count),
                tags: [topic]
            )
            semanticMemories.append(semantic)
        }
        return semanticMemories
    }

    /// 从情景记忆提取主题（简化版：取前 10 个字符作为 topic key）
    static func extractTopic(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(10))
    }

    /// 检查是否有里程碑事件
    public static func checkMilestones(growthState: GrowthState) -> [Memory] {
        var milestones: [Memory] = []
        if growthState.stage == .juvenile && growthState.totalXP >= 500 && growthState.totalXP < 550 {
            milestones.append(Memory(kind: .milestone, content: "长大成少年了！", importance: 5))
        }
        if growthState.streakDays == 7 {
            milestones.append(Memory(kind: .milestone, content: "连续陪伴 7 天", importance: 4))
        }
        if growthState.streakDays == 30 {
            milestones.append(Memory(kind: .milestone, content: "连续陪伴 30 天", importance: 5))
        }
        return milestones
    }
}
```

### Task 4: DiaryWriter（日记）

```swift
// Sources/SoulCore/Memory/DiaryWriter.swift
import Foundation

public enum DiaryWriter {
    /// 生成今日日记条目（markdown）
    public static func writeEntry(date: Date, events: [Memory], mood: Mood, stage: Stage) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "zh_CN")
        let dateStr = f.string(from: date)
        var lines = ["# \(dateStr) 的日记\n"]
        // 开头（按阶段调整口吻）
        switch stage {
        case .egg: lines.append("……")
        case .baby: lines.append("今天…嗯…发生了…什么呢…")
        case .juvenile: lines.append("今天过得挺有意思的！")
        case .adult: lines.append("今天的一天，值得记一下。")
        }
        // 事件
        if !events.isEmpty {
            lines.append("\n## 今天发生的事\n")
            for e in events.prefix(5) {
                lines.append("- \(e.content)")
            }
        }
        // 心情
        let moodCN = ["calm": "平静", "happy": "开心", "sleepy": "犯困",
                       "missing": "想你", "sleeping": "睡着"][mood.rawValue] ?? "平静"
        lines.append("\n心情：\(moodCN)")
        return lines.joined(separator: "\n")
    }

    /// 保存日记到磁盘
    public static func save(entry: String, date: Date, to directory: URL) throws {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let filename = "\(f.string(from: date)).md"
        let path = directory.appendingPathComponent(filename)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try entry.write(to: path, atomically: true, encoding: .utf8)
    }
}
```

### Task 5: ArchiveExporter（导出/导入）

```swift
// Sources/SoulCore/Memory/ArchiveExporter.swift
import Foundation

public enum ArchiveExporter {
    public struct LifeArchive: Codable {
        public var version: Int = 1
        public var exportedAt: Date
        public var memories: [Memory]
        public var growthState: GrowthState
        public var soulState: SoulState
    }

    public static func export(memories: [Memory], growth: GrowthState, soul: SoulState) throws -> Data {
        let archive = LifeArchive(exportedAt: Date(), memories: memories,
                                   growthState: growth, soulState: soul)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(archive)
    }

    public static func importArchive(_ data: Data) throws -> LifeArchive {
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return try dec.decode(LifeArchive.self, from: data)
    }
}
```

### Task 6: MemoryTools（remember/recall tool definitions）

register with ToolRegistry, stage-gated to `.juvenile+`.

### Task 7: PersonaSynth 记忆染色

Inject top-N relevant memories into the system prompt.

### Task 8: DaemonSoul 记忆集成

### Task 9: M4 验收 + 打标 v0.5.0-m4

---

## 自检记录

1. **Spec 覆盖**：记忆模型 ✅(T0) · CRUD ✅(T1) · 检索 ✅(T2) · 做梦 ✅(T3) · 日记 ✅(T4) · 导出导入 ✅(T5) · 工具 ✅(T6) · prompt 染色 ✅(T7) · daemon 集成 ✅(T8)。
2. **类型一致**：`Memory` 独立 Codable · `GrowthState`/`SoulState`/`Mood`/`Stage` 复用既有 · `MemoryStore` 线程安全（NSLock）。
