# mpet — 会长大的桌面电子生命（soul-first 重建）

mpet 是住在你 Mac 上的电子生命：一只有自己人生的小生命，恰好住在你的电脑里。
灵魂是常驻 daemon 里的一个 LLM agent；身体（桌面 App）、信使（P2P 社交）、插件都是它的外设。

- **完整蓝图**：[`docs/superpowers/specs/2026-06-11-mpet-soul-design.md`](docs/superpowers/specs/2026-06-11-mpet-soul-design.md)（理想态 PRD v2.5）
- **发布阶梯**：M0–M9 **全部交付**（`v1.0.0-m9`，283 单测全绿，见 spec §0/§13）
- **插件开发**：[`docs/PLUGIN-GUIDE.md`](docs/PLUGIN-GUIDE.md)（第三方开放标准）+ [`examples/plugins/`](examples/plugins/)
- **形象穿刺**（SVG-first，可在浏览器打开把玩）：[`spikes/svg-pet/`](spikes/svg-pet/)

## 它会什么（M0–M9）

- **有灵魂**：事件驱动 LLM agent 循环（任意 OpenAI 兼容端点）+ 反射弧 + 唤醒策略 + 一颗心并发
- **活着**：心情/昼夜/睡觉/待机小动作 + 回归问候 + 求关注 + 身体缺席系统通知兜底
- **会长大**：XP/羁绊/streak 经济（日封顶 150）+ fuel log 曲线 + 蛋→幼崽→少年→成年阶段门控
- **记得你**：remember/recall 工具 + 做梦蒸馏 + 日记 + 防说错（置信度）+ 生命档案导出导入
- **是你创造的**：外观基因组（JSON 参数）× 四套阶段骨架 → SVG 渲染 + 共创蜕变仪式 + 孵化 onboarding
- **有自己的人生**：爪子分级授权 + 它的房间/小项目 + 里程碑纪念日 + 性格永续分化
- **有朋友**：身份密钥（孵化即领）+ ticket 加好友 + 确定性双签对战 + 宿敌 + 档案含密钥换机不失身份
- **有社交生活**：广场见闻（注入防御）+ 拉黑/举报/仅好友/社交总开关 + 朋友圈天梯 + 徽章图鉴
- **收礼物**：插件标准对外开放（manifest+权限确认+进程管理+MCP 桥）+ 拆礼物仪式

### 架构（六个 SPM 目标）

- **`SoulCore`** — 纯逻辑库，283 单测全覆盖（时钟可注入、假 LLM 测试架）
- **`mpet-soul`** — 守护进程（Unix socket NDJSON 服务 + 全部接线）
- **`MpetApp`** — macOS 桌面身体（SwiftUI + WKWebView SVG 渲染 + 聊天 + 设置 + 状态菜单）
- **`mpet-cc-watcher`** — 第一方旗舰插件（Claude Code 守望：hook + spool + 喊人 + 口粮）
- **`soulctl`** — 调试客户端
- **`SoulCoreTests`** — XCTest 套件

### 快速起跑

```bash
swift build && swift test                     # 构建 + 283 测试

# 1) 配置任意 OpenAI 兼容端点 —— 二选一：
export MPET_BASE_URL="https://你的端点/v1" MPET_API_KEY="..." MPET_MODEL="..."
#    或写 ~/.config/mpet/soul.json：{"llm":{"baseURL":"…","apiKey":"…","model":"…"}}

# 2) 探测端点能力（工具调用必须合格）
swift run soulctl probe

# 3) 跑灵魂（常驻）
swift run mpet-soul

# 4) 跑桌面身体（另开终端）
swift run MpetApp

# 5) 装 CC 守望（另开终端，可选）
swift run mpet-cc-watcher --install-hook && swift run mpet-cc-watcher

# 6) 终端互动
swift run soulctl status / chat 你好呀 / event click / sense cc.waiting alert
```

### 产品化路线（阶梯外）

iroh Rust courier 真实组网 · Ed25519 真实签名（API 已定形）· .app 打包公证 · 表现能力面 · 全球天梯 · 插件商店 —— 见 spec §13 阶梯外清单。
