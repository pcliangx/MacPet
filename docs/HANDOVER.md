# mpet 交接文档（会话重启用）

> 更新：2026-06-14 ｜ **全阶梯 M0–M9 交付完成，v1.0.0-m9**。新会话先读本文档 + spec §0 进度仪表盘。

## 一、项目一句话

mpet = 住在 Mac 上的电子生命：灵魂是常驻 daemon 里的 LLM agent（任意 OpenAI 兼容端点），身体/信使/插件都是外设。**自用优先，soul-first 推倒重构，全部从零 TDD（旧仓库已废弃）。**

## 二、关键路径

| 物件 | 位置 |
|---|---|
| 仓库（本地） | `/Users/pc2026/Documents/DevTools/MacPet`，分支 `main` |
| 仓库（远程） | `git@github.com:pcliangx/MacPet.git`（origin；**注意：本地领先大量提交待推送**） |
| 设计文档（唯一蓝图） | `docs/superpowers/specs/2026-06-11-mpet-soul-design.md`（v2.5；§0=live 进度全✅） |
| 各里程碑实现计划 | `docs/superpowers/plans/`（M0–M9 共 10 份） |
| 第三方插件文档 | `docs/PLUGIN-GUIDE.md` |
| 示例插件 | `examples/plugins/`（weather sense + dice tool） |
| 形象穿刺 | `spikes/svg-pet/` |

## 三、交付总览（M0–M9 全部 ✅）

| 里程碑 | 标签 | 测试数 | 核心交付 |
|---|---|---|---|
| M0 灵魂胚胎 | `v0.1.0-m0` | 42 | agent 循环 + 反射弧 + 外设协议族 v0 + soulctl |
| M1 借壳还魂 | `v0.2.0-m1` | 69 | MpetApp 桌面身体 + cc-watcher 插件 + Keychain + launchd |
| M2 它活了 | `v0.3.0-m2` | 106 | LifecyclePhase + 回归问候 + 求关注 + 心跳 + 缺席通知 |
| M3 它开始长大 | `v0.4.0-m3` | 128 | XP/羁绊/streak 经济 + fuel 曲线 + DevMode + 成长 UI |
| M4 它记得你 | `v0.5.0-m4` | 158 | Memory + remember/recall + 做梦蒸馏 + 日记 + 档案导出 |
| M5 它是你创造的 | `v0.6.0-m5` | 173 | AppearanceGenome + GenomeRenderer + 共创仪式 + 孵化 |
| M6 它有自己的人生 | `v0.7.0-m6` | 198 | 爪子授权 + 房间/项目 + 里程碑纪念日 + 性格分化 |
| M7 它有朋友了 | `v0.8.0-m7` | 226 | PetIdentity + FriendTicket + BattleEngine + 档案 v2 含密钥 |
| M8 广场与天梯 | `v0.9.0-m8` | 252 | PlazaGossip 注入防御 + SocialSafety + FriendLadder + 徽章 |
| M9 它收到了礼物 | `v1.0.0-m9` | **283** | PluginManifest + 权限 + 进程管理 + MCP 桥 + 礼物仪式 + 文档 |

**最终状态：283 单测全绿，debug + release 双构建通过。**

## 四、SPM 目标结构

```
Package.swift (6 targets)
├── SoulCore (库) — Time/Protocol/Perception/Reflex/Brain/State/Client/Plugin/
│                    Security/System/Lifecycle/Growth/Memory/Appearance/Claws/Life/Social
├── mpet-soul (可执行) — daemon
├── soulctl (可执行) — 调试客户端
├── mpet-cc-watcher (可执行) — CC 插件
├── MpetApp (可执行) — macOS 桌面 App
└── SoulCoreTests — 283 用例
```

## 五、产品化路线（阶梯外，spec §13「阶梯外清单」）

以下为刻意留到产品化阶段的硬骨头（spec 原文即标远期/独立 crate）：

1. **mpet-courier Rust crate（iroh 1.0）**：Swift 侧 CourierProtocol 已就绪，真实 P2P 网络互联需独立 Rust 进程
2. **Ed25519 真实签名**：PetIdentity 当前为简化签名（API 形状已定），产品化换 CryptoKit
3. **真实 LLM 端点验收**：chat/probe 路径需配置 `~/.config/mpet/soul.json` 后实测
4. **App 打包 .app + 公证**：当前 swift run 形态
5. 表现能力面 / 全球天梯 / 插件商店 / 多设备同步（§13 阶梯外清单）

## 六、已踩过的坑（接续开发必读）

- `dispatchMain()` 在异步 main 里 SIGTRAP → 用 `await withUnsafeContinuation`
- daemon stdout 重定向全缓冲 → `fflush(stdout)`
- `FileManager.replaceItemAt` 目标不存在抛错 → fallback `moveItem`
- `swift test --filter` 尾部 "Swift Testing: 0 tests" 是良性双 runner
- Codable 默认值不会用于缺失 key → 需 `decodeIfPresent` 自定义 init（PluginManifest 即例）
- Mood 加 case 后所有 switch 需补全（M2 加 sleeping 时全仓修过一轮）
- actor 方法在同步闭包里调用需包 `Task { await ... }`
- 子 agent 派单约束：互不相交文件集才可并行；只 `git add` 自己的文件

## 七、环境备忘

- LLM 端点配置：`export MPET_BASE_URL/MPET_API_KEY/MPET_MODEL` 或 `~/.config/mpet/soul.json`；先 `swift run soulctl probe`
- 验收/测试启动过 daemon 后：`pkill -f mpet-soul` 并清 `soul.sock`
- **待办：`git push origin main --tags`**（此前网络不通未推送）

## 八、快速起跑（使用者视角）

```bash
# 1. 配置端点
export MPET_BASE_URL="https://你的端点/v1" MPET_API_KEY="..." MPET_MODEL="..."
swift run soulctl probe          # 能力探测

# 2. 跑灵魂
swift run mpet-soul

# 3. 跑桌面身体（另开终端）
swift run MpetApp

# 4. 装 CC 守望插件（另开终端）
swift run mpet-cc-watcher --install-hook
swift run mpet-cc-watcher

# 5. 玩
swift run soulctl chat 你好呀
swift run soulctl sense cc.waiting alert
```
