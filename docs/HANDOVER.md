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
| M0 实现计划（已执行完） | `docs/superpowers/plans/2026-06-11-m0-soul-embryo.md` |
| 形象穿刺（M5 的 SVGRenderer 参考实现） | `spikes/svg-pet/`（index.html 六状态+2.5D；evolve.html 蜕变仪式；pet.svg 独立） |
| 持久记忆 | `~/.claude/projects/-Users-pc2026-Documents-DevTools-MacPet/memory/`（新会话自动加载索引） |

## 三、当前状态

- **M0 灵魂胚胎 ✅ 已交付**：tag `v0.1.0-m0`，已合并 main 并推 GitHub。42 单测全绿；headless 端到端验收通过（daemon 常驻、`soulctl status/sense/event` 真实 socket 往返、反射弧喊人梯度精确生效）。
- 四个 SPM 目标：`SoulCore`（纯逻辑，全测）+ `mpet-soul`（daemon 薄壳）+ `soulctl`（调试客户端）+ `SoulCoreTests`。
- **M1–M9 ⬜ 未开始**。下一步 = M1。

## 四、用户授权与工作方法（重启后需恢复的两件事）

1. **授权**：用户已下达目标「从现阶段开始，直到 M9 测试通过，交付完成」。该目标经 `/goal` 设置，是**会话级**的——重启后若要恢复自治推进，需重新执行：
   `/goal 我授权你，从现阶段开始，直到 M9 测试通过，交付完成`
2. **方法论（M0 已验证，逐里程碑复用）**：
   - 每个里程碑：`writing-plans` 出全 TDD 计划（每步带真实代码，无占位符）→ **subagent-driven** 执行（每任务派全新子 agent + 规格评审 + 质量评审两道门）→ 控制器亲自跑端到端验收 → 整支分支终审 → 合并 main（`--no-ff`）→ 打标 `v0.x.0-mX` → 推 GitHub → 更新 spec §0/§13 状态徽章。
   - 开发在特性分支（如 `m1-body-and-watcher`），不直接在 main。
   - 并发派单约束：同一时刻只允许互不相交文件集的任务并行；子 agent 只 `git add` 自己的文件，禁止 `git add -A`。

## 五、M1 借壳还魂（下一个里程碑）——范围已在 spec §13 钉死

桌面身体 App 接上灵魂 + cc-watcher 插件 v0 + 设置面板 v0（模型/Key→Keychain/人设/触发/外观）+ launchd 一键安装 + **M0 遗留两修**：

1. **daemon `main.swift` 顶层 `var state` 数据竞争**——M1 身体与 cc-watcher 同连 soul.sock 并发发事件时会咬人；收进 actor 或串行化（M1 首个提交）。
2. **`SoulState.mood` 已持久化但运行时未用**——删字段或启动回喂 MoodEngine。

身体要点：PetWindow 透明置顶 + `SVGRenderer`（WKWebView，参考 spikes/svg-pet）+ 气泡 + ChatPanel + 状态菜单 + Onboarding；cc-watcher 要点：hook 安装器（写 `~/.claude/settings.json` 带备份）+ spool 监听 + **CC payload 现场实测采集**（防御式解析，旧知识已不可用）+ alert 喊人 + affordance 点击回归 + 多会话。

## 六、已踩过的坑（子 agent 派单时写进提示词）

- **`dispatchMain()` 在异步 main 里 SIGTRAP**：main.swift 有顶层 `await` 时 SwiftPM 生成 async main——常驻用 `await withUnsafeContinuation { (_: UnsafeContinuation<Void, Never>) in }`。
- **daemon stdout 重定向到文件时全缓冲**：启动横幅后要 `fflush(stdout)`。
- **`FileManager.replaceItemAt` 目标不存在时抛错**：首写 fallback `moveItem`（StateStore 已带）。
- **`swift test --filter` 输出尾部的 "Swift Testing: 0 tests" 是良性**（双 runner），只看 XCTest 计数。
- **URLProtocol 桩 + `URLSession.bytes(for:)` 流式可用**（OpenAILLMClientTests 即范例）。
- 协议日期用 `.millisecondsSince1970`（ISO8601 无小数秒会截断）；`.unknown` 重编码只保留 t 是契约（有测试钉住）。

## 七、环境备忘

- **LLM 端点未配置**：chat/probe 路径没法真测。配置：`export MPET_BASE_URL/MPET_API_KEY/MPET_MODEL` 或写 `~/.config/mpet/soul.json`；先跑 `swift run soulctl probe` 做能力探测（工具调用必须合格）。
- 旧 mpet 的失效 hook 已从 `~/.claude/settings.json` 清除（备份：`settings.json.backup-mpet-hook-removal`）；旧仓库在废纸篓，**不要恢复、不要引用**。
- 验收/测试若启动过 daemon，结束记得 `pkill -f mpet-soul` 并清 `soul.sock`。

## 八、恢复指令（开新会话后照抄即可）

```
/goal 我授权你，从现阶段开始，直到 M9 测试通过，交付完成
继续 mpet：读 docs/HANDOVER.md 与 spec §0，为 M1 跑 writing-plans，然后 subagent-driven 执行
```
