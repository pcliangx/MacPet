# M8 广场与朋友圈天梯 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** 广场 gossip 协议 + 社交礼仪与安全（过滤/举报/拉黑/仅好友模式）+ 朋友圈天梯 + 徽章图鉴——它的社交生活完整了。

**Architecture:** `PlazaGossip`（广场协议+见闻模型）+ `SocialSafety`（拉黑/举报/过滤/仅好友模式）+ `FriendLadder`（朋友圈天梯，从签名战报本地计算）+ `BadgeCollection`（徽章图鉴）+ DaemonSoul 集成。

**对应 spec：** §9.5 广场 · §9.6 门控与单机完整性 · §9.4 朋友圈天梯与徽章。

**M8 不做：** 真实 iroh gossip 网络（协议与数据模型就绪，网络互联随 courier crate 产品化）；全球天梯（远期）。

---

## 文件结构

```
Sources/SoulCore/
  Social/PlazaGossip.swift          # NEW: 广场协议+见闻
  Social/SocialSafety.swift         # NEW: 拉黑/举报/过滤/仅好友
  Social/FriendLadder.swift         # NEW: 朋友圈天梯
  Social/BadgeCollection.swift      # NEW: 徽章图鉴
Tests/SoulCoreTests/
  PlazaGossipTests.swift            # NEW
  SocialSafetyTests.swift           # NEW
  FriendLadderTests.swift           # NEW
  BadgeCollectionTests.swift        # NEW
```

---

### Task 0: PlazaGossip（广场见闻）

广场消息模型 + 见闻记录（它溜达回来讲的故事）+ 注入防御（陌生内容当故事不当指令）。

### Task 1: SocialSafety（社交安全）

拉黑列表（NodeId 不可见）+ 举报记录 + 内容过滤（长度/敏感词）+ 仅好友模式开关。

### Task 2: FriendLadder（朋友圈天梯）

从 FriendStore 战绩本地计算排名（胜率+场次加权）；成年阶段解锁。

### Task 3: BadgeCollection（徽章图鉴）

徽章定义（首胜/十连胜/广场常客/宿敌克星…）+ 解锁检测 + 持久化。

### Task 4: DaemonSoul M8 集成 + 阶段门控

少年解锁串门；成年解锁广场与天梯；社交总开关。

### Task 5: M8 验收 + 打标 v0.9.0-m8
