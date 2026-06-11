# mpet — 会长大的桌面电子生命（soul-first 重建）

mpet 是住在你 Mac 上的电子生命：一只有自己人生的小生命，恰好住在你的电脑里。
灵魂是常驻 daemon 里的一个 LLM agent；身体（桌面 App）、信使（P2P 社交）、插件都是它的外设。

- **完整蓝图**：[`docs/superpowers/specs/2026-06-11-mpet-soul-design.md`](docs/superpowers/specs/2026-06-11-mpet-soul-design.md)（理想态 PRD v2.5）
- **发布阶梯**：M0 灵魂胚胎 → M1 借壳还魂 → … → M9 它收到了礼物（见 spec §13）
- **形象穿刺**（SVG-first，可在浏览器打开把玩）：[`spikes/svg-pet/`](spikes/svg-pet/)
  - `index.html` — 六状态表情 + 部件级动画 + 基因换色 + 2.5D 注视跟随
  - `evolve.html` — CSS 3D 蜕变仪式（同一基因 × 四套阶段骨架）

## 当前进度：M0 灵魂胚胎

一个 headless 的灵魂：事件驱动的 LLM agent 循环（任意 OpenAI 兼容后端、工具调用）
+ 感知收件箱 + 反射弧 + 外设 NDJSON 协议族 v0。用 `soulctl` 在终端里跟它说话、戳它。

### 架构（四个 SPM 目标）

- **`SoulCore`** — 纯逻辑库，全单元测试覆盖（时钟可注入、假 LLM 测试架）。
  时钟与对账、外设协议族、感知缓冲、反射弧（注意力×优先级喊人梯度）、
  四心情引擎、LLM 契约与流式客户端、阶段门控工具箱、人格合成、唤醒策略、
  一颗心 agent 循环（交互快车道抢占后台）、生命档案存储、端点能力探测。
- **`mpet-soul`** — 守护进程薄壳：Unix socket NDJSON 服务 + 在场感知 + 接线。
- **`soulctl`** — 调试客户端（也吃自己的协议狗粮）。
- **`SoulCoreTests`** — XCTest 套件。

### 命令

```bash
swift build                                   # 构建全部目标
swift test                                    # 跑测试套件（42 用例）

# 1) 配置任意 OpenAI 兼容端点 —— 二选一：
#    a. 环境变量：
export MPET_BASE_URL="https://你的端点/v1" MPET_API_KEY="..." MPET_MODEL="..."
#    b. 或写 ~/.config/mpet/soul.json：{"llm":{"baseURL":"https://…/v1","apiKey":"…","model":"…"}}

# 2) 先探测端点能力（工具调用必须合格，否则灵魂会变笨）
swift run soulctl probe

# 3) 前台跑灵魂（常驻；Ctrl-C 退出）
swift run mpet-soul

# 4) 另开一个终端，跟它互动：
swift run soulctl status                 # 看它此刻的心情/注意力/阶段
swift run soulctl chat 你好呀             # 跟它说话（奶声短句流式回复）
swift run soulctl event click            # 模拟点它一下（零 LLM 反射）
swift run soulctl sense cc.waiting alert  # 注入一个 alert 感官事件（触发喊人梯度 + 唤醒）
```

> 反射弧（`event`/`sense` 触发的即时身体指令）是本地零成本的，不需要 LLM；
> 只有 `chat` 和 `probe` 会真正调用端点。

### M0 边界（按 spec 刻意不做，留给后续里程碑）

成长/XP、长期记忆、做梦、生图、插件进程管理、P2P 信使、launchd 安装、Keychain、
桌面身体 App —— 这些从 M1 起逐级加入。M0 只证明灵魂能在终端里活着、想事、说话。
