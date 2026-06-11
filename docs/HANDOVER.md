# mpet 交接文档（会话重启用）

> 更新：2026-06-12 ｜ 用途：电脑重启/新会话接续开发。新会话先读本文档 + spec §0 进度仪表盘。

## 一、项目一句话

mpet = 住在 Mac 上的电子生命：灵魂是常驻 daemon 里的 LLM agent（任意 OpenAI 兼容端点），身体/信使/插件都是外设。**自用优先，soul-first 推倒重构，全部从零 TDD（旧仓库已废弃，不引用任何旧代码）。**

## 二、关键路径

| 物件 | 位置 |
|---|---|
| 仓库（本地） | `/Users/pc2026/Documents/DevTools/MacPet`，分支 `main` |
| 仓库（远程） | `git@github.com:pcliangx/MacPet.git`（origin，已设上游跟踪） |
| 设计文档（唯一蓝图） | `docs/superpowers/specs/2026-06-11-mpet-soul-design.md`（v2.5；§0=live 进度，§13=阶梯+阶梯外清单，§13.1=里程碑↔章节对应，覆盖度已闭合 100%） |
| M0 实现计划 | `docs/superpowers/plans/2026-06-11-m0-soul-embryo.md` |
| M1 实现计划 | `docs/superpowers/plans/2026-06-12-m1-body-and-watcher.md` |
| M2 实现计划 | `docs/superpowers/plans/2026-06-12-m2-it-lives.md` |
| M3 实现计划 | `docs/superpowers/plans/2026-06-13-m3-growing-up.md` |
| M4 实现计划 | `docs/superpowers/plans/2026-06-13-m4-remembers-you.md` |
| M5 实现计划 | `docs/superpowers/plans/2026-06-13-m5-your-creation.md` |
| M6 实现计划 | `docs/superpowers/plans/2026-06-14-m6-own-life.md` |
| 形象穿刺（M5 的 SVGRenderer 参考实现） | `spikes/svg-pet/`（index.html 六状态+2.5D；evolve.html 蜕变仪式；pet.svg 独立） |
| 持久记忆 | `~/.claude/projects/-Users-pc2026-Documents-DevTools-MacPet/memory/`（新会话自动加载索引） |

## 三、当前状态

- **M0 灵魂胚胎 ✅ 已交付**：tag `v0.1.0-m0`，42 单测全绿
- **M1 借壳还魂 ✅ 已交付**：tag `v0.2.0-m1`，69 单测全绿（+27 新增）
  - DaemonSoul actor（修复 M0 数据竞争 + mood 运行时回写）
  - SoulClient actor（NWConnection 客户端，自动重连）
  - MpetApp macOS 桌面 App（SwiftUI + WKWebView SVGRenderer + ChatPanel + BubbleView + StatusMenu + SettingsPanel + Onboarding）
  - mpet-cc-watcher 插件（HookInstaller + CCSpoolMonitor + CCEvent 防御式解析 + affordance 回归）
  - KeychainStore + LaunchdInstaller
- **M2 它活了 ✅ 已交付**：tag `v0.3.0-m2`，106 单测全绿（+37 新增）
  - LifecyclePhase（active/drowsy/asleep/returning 状态机）
  - ReturnDetector（离开→回归问候）
  - AttentionSeeker（求关注+预算）
  - IdleActions（待机小动作库）
  - HeartbeatScheduler（定时心跳，日预算+间隔）
  - AbsentBodyNotifier（osascript 系统通知兜底）
  - MoodEngine v2（sleeping 心情+lifecycle 集成）
  - DaemonSoul 增强（60 秒 lifecycle 循环+heartbeat+求关注+回归问候+缺席通知）
- **M3 它开始长大 ✅ 已交付**：tag `v0.4.0-m3`，128 单测全绿（+22 新增）
  - GrowthState（XP/羁绊/streak/阶段进度）
  - EconomyEngine（XP 计算/日封顶 150/streak 倍率/羁绊增量）
  - FuelProcessor（fuel→XP log 递减曲线）
  - GrowthStateStore（原子写成长档案）
  - DevMode（XP 注入/阶段跳转/streak 覆盖/重置）
  - DaemonSoul growth 集成（applyXP/addBond/fuelReport/dailyRollover）
  - cc-watcher fuel.report（PostToolUse token 估算）
  - MpetApp 成长感知 UI（状态菜单 XP/streak/bond/progress）
- **M4 它记得你 ✅ 已交付**：tag `v0.5.0-m4`，158 单测全绿（+30 新增）
  - Memory 模型（episodic/semantic/milestone + 置信度/重要度/出处）
  - MemoryStore（CRUD + 纠正 + 访问追踪）
  - MemorySearch（关键词+时近+重要度打分）
  - DreamEngine（情景→语义蒸馏 + 里程碑检测）
  - DiaryWriter（markdown 日记，阶段口吻）
  - ArchiveExporter（生命档案导出/导入 v0）
  - remember/recall 工具（juvenile+ 阶段门控）
  - PersonaSynth 记忆染色 + 防说错
- **M5 它是你创造的 ✅ 已交付**：tag `v0.6.0-m5`，173 单测全绿（+15 新增）
  - AppearanceGenome（体色/耳形/眼型/尾巴/斑纹 JSON 参数）
  - GenomeRenderer（基因组×阶段×心情→SVG HTML）
  - CoCreationCeremony（蜕变宣告+候选基因组）
  - MpetApp 数据驱动 SVGRenderer + 孵化 onboarding
- **M6 它有自己的人生 ✅ 已交付**：tag `v0.7.0-m6`，198 单测全绿（+25 新增）
  - ClawAuthManager（分级授权：freeHome/freeRead/ask/never）
  - PetRoom/PetRoomStore（它的房间：物品+礼物）
  - PetProject/PetProjectStore（小项目：进度+状态）
  - MilestoneTracker（纪念日+新里程碑发现）
  - PersonalityDrift（性格永续分化）
- **M7–M9 ⬜ 未开始**。下一步 = M7。

## 四、用户授权与工作方法（重启后需恢复的两件事）

1. **授权**：用户已下达目标「从现阶段开始，直到 M9 测试通过，交付完成」。该目标经 `/goal` 设置，是**会话级**的——重启后若要恢复自治推进，需重新执行：
   `/goal 我授权你，从现阶段开始，直到 M9 测试通过，交付完成`
2. **方法论（M0+M1 已验证，逐里程碑复用）**：
   - 每个里程碑：`writing-plans` 出全 TDD 计划（每步带真实代码，无占位符）→ **subagent-driven** 执行（并行派出子 agent 实现独立组件 + 规格评审 + 质量评审两道门）→ 控制器亲自跑端到端验收 → 整支分支终审 → 合并 main（`--no-ff`）→ 打标 `v0.x.0-mX` → 推 GitHub → 更新 spec §0/§13 状态徽章。
   - 开发在特性分支（如 `m1-body-and-watcher`），不直接在 main。
   - 并发派单约束：同一时刻只允许互不相交文件集的任务并行；子 agent 只 `git add` 自己的文件，禁止 `git add -A`。

## 五、M7 它有朋友了（下一个里程碑）——范围已在 spec §13 钉死

mpet-courier v0（iroh 直连/relay 兜底）+ 身份密钥（孵化即领）+ ticket 加好友 + 访客宠物运行时 + 串门 + 双签名异步对战（带 sim 版本号）+ 宿敌——**无账号系统**；档案导出扩展**含身份密钥**（换机不失身份）

## 六、已踩过的坑（子 agent 派单时写进提示词）

- **`dispatchMain()` 在异步 main 里 SIGTRAP**：main.swift 有顶层 `await` 时 SwiftPM 生成 async main——常驻用 `await withUnsafeContinuation { (_: UnsafeContinuation<Void, Never>) in }`。
- **daemon stdout 重定向到文件时全缓冲**：启动横幅后要 `fflush(stdout)`。
- **`FileManager.replaceItemAt` 目标不存在时抛错**：首写 fallback `moveItem`（StateStore 已带）。
- **`swift test --filter` 输出尾部的 "Swift Testing: 0 tests" 是良性**（双 runner），只看 XCTest 计数。
- **URLProtocol 桩 + `URLSession.bytes(for:)` 流式可用**（OpenAILLMClientTests 即范例）。
- 协议日期用 `.millisecondsSince1970`（ISO8601 无小数秒会截断）；`.unknown` 重编码只保留 t 是契约（有测试钉住）。
- **HookInstaller 幂等性**：removeMpetHooks 直接移除 Notification key（不靠 command 子串匹配，因测试用 `echo test` 不含 "mpet"）。
- **CCSpoolMonitor 备份时间戳**：用毫秒精度防同秒冲突。
- **SoulConfig 在 mpet-soul target 里**：MpetApp 不能 import——SettingsPanel 用 private MpetSoulConfig 镜像读取同一路径。
- **CC hook 的 stdin 是 JSON**（不是环境变量）：hook 命令用 `cat >` 写 spool 文件，由 CCSpoolMonitor 异步解析。
- **SoulClient/CCSpoolMonitor handler 是同步闭包**：actor 调用需包装在 `Task { await ... }` 内。

## 七、环境备忘

- **LLM 端点未配置**：chat/probe 路径没法真测。配置：`export MPET_BASE_URL/MPET_API_KEY/MPET_MODEL` 或写 `~/.config/mpet/soul.json`；先跑 `swift run soulctl probe` 做能力探测（工具调用必须合格）。
- 旧 mpet 的失效 hook 已从 `~/.claude/settings.json` 清除（备份：`settings.json.backup-mpet-hook-removal`）；旧仓库在废纸篓，**不要恢复、不要引用**。
- 验收/测试若启动过 daemon，结束记得 `pkill -f mpet-soul` 并清 `soul.sock`。

## 八、SPM 目标结构（M1 后）

```
Package.swift (6 targets)
├── SoulCore (库) — 全单测，含 Client/Plugin/Security/System/State 子模块
├── mpet-soul (可执行) — daemon 薄壳
├── soulctl (可执行) — 调试客户端
├── mpet-cc-watcher (可执行) — CC 插件
├── MpetApp (可执行) — macOS 桌面 App（SwiftUI + AppKit + WebKit）
└── SoulCoreTests (测试) — 69 用例
```

## 九、恢复指令（开新会话后照抄即可）

```
/goal 我授权你，从现阶段开始，直到 M9 测试通过，交付完成
继续 mpet：读 docs/HANDOVER.md 与 spec §0，为 M2 跑 writing-plans，然后 subagent-driven 执行
```
