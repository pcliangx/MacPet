# mpet 插件开发指南（第三方开放标准 v1）

> M9 起对外开放。装插件 = 送宠物一个礼物：它会拆开、给玩具起昵称、试用、写进日记。

## 一、一切皆外设

mpet 的插件是**独立进程**，通过 stdio（或 Unix socket）与灵魂用 **NDJSON**（一行一个 JSON 消息）通信。语言不限——shell、Python、Node、Rust 都行。

插件能加四种能力（spec §10.1）：

| 能力面 | 进哪里 | 说明 |
|---|---|---|
| **感官 sense** | 事件 → 感知收件箱 → 唤醒策略 | 优先级三档：`ambient`（只进上下文）/ `nudge`（预算内可唤醒）/ `alert`（立即唤醒+喊人梯度） |
| **爪子 tool** | function-calling 工具箱 | 只能申领 `free-read` 或 `ask` 级；`never`/`free-home` 不可申领 |
| **口粮 fuel** | 当日口粮信号 → 成长经济 | 曲线/递减/封顶永远在核心；**喂养权是敏感权限，安装时单独确认** |
| **事件动作 affordance** | `sense.event` 携带 `actions[]` | 点击宠物/气泡 → 灵魂回调你的插件 |

**永不可插**：人格、记忆内核、成长经济规则——灵魂不外包。

## 二、plugin.json（manifest）

```json
{
  "name": "weather",
  "displayName": "天气感知",
  "version": "0.1.0",
  "kind": ["sense", "tool"],
  "entry": { "type": "exec", "cmd": "./weather.sh" },
  "permissions": ["network"],
  "tools": [ { "name": "now", "tier": "free-read" } ],
  "senses": [ { "id": "weather.changed", "priority": "ambient", "dailyBudget": 8 } ],
  "persona_hints": { "toyName": "气象风向标", "intro": "能闻出今天会不会下雨" }
}
```

- `entry.type`：`exec`（原生外设）或 `mcp`（现成 MCP server，见下）
- `permissions`：安装时**逐条向用户确认**（`network`、`read:<path>`、`notify`、`fuel`）
- `persona_hints`：宠物怎么称呼、怎么介绍你的"玩具"——礼物仪式的素材

## 三、协议（NDJSON 消息集，exec 型）

### 握手

启动后灵魂发给你（或你主动发）：

```json
{"t":"hello","role":"plugin","name":"weather","proto":1}
```

灵魂回：

```json
{"t":"hello.ok","proto":1,"soulVersion":"1.0.0-m9"}
```

### 感官（插件 → 灵魂）

```json
{"t":"sense.event","percept":{"id":"e1","kind":"weather.changed","priority":"ambient","payload":{},"actions":[],"at":1760000000000}}
```

带 affordance（可点击动作）：

```json
{"t":"sense.event","percept":{"id":"e2","kind":"ci.failed","priority":"alert","payload":{"title":"CI 挂了"},"actions":[{"id":"open-ci","label":"带我去看"}],"at":1760000000000}}
```

用户点击后灵魂回调你：

```json
{"t":"action.invoke","eventId":"e2","actionId":"open-ci"}
```

### 工具（灵魂 → 插件 → 灵魂）

```json
{"t":"tool.call","id":"c1","name":"roll","args":{}}
{"t":"tool.result","id":"c1","ok":true,"content":"骰子摇出了 4 点！"}
```

### 口粮（插件 → 灵魂，需 fuel 权限）

```json
{"t":"fuel.report","date":"2026-06-14","raw":12345}
```

核心套 log 递减曲线 + 日封顶——你只管报原始信号，多报无益。

### 生命周期

- `{"t":"ping"}` ↔ `{"t":"pong"}`：心跳
- 崩溃不连坐：你的插件崩了只影响你自己，灵魂按策略重启（最多 3 次，之后自动停用）
- 未知消息类型必须容忍（向前兼容）

## 四、MCP 桥（entry.type = "mcp"）

已有 MCP server？不用写一行 mpet 代码：

```json
{ "entry": { "type": "mcp", "cmd": "npx my-mcp-server" } }
```

- 你的 MCP tools 自动进工具箱（**默认「先问」级**，用户可降级）
- notifications 映射为 `ambient` 感官事件
- MCP server 不需要知道 mpet 存在

## 五、规矩（必读）

1. **分寸**：你的事件不绕过唤醒预算（manifest `dailyBudget` + 全局上限）。吵闹的插件不能让宠物变烦人。
2. **注入防御**：你取回的外部数据会被当资料、不当指令。别试图在 payload 里夹带指令。
3. **不开放大脑**：插件不能调用 LLM sampling——它用工具，工具不用它。
4. **社交上下文禁用**：宠物和访客玩耍/对战/逛广场时，你的工具不可用。
5. **信任级别**：v1 无沙箱（= VS Code 扩展：装 = 信任其代码）；签名与沙箱在路线图上。

## 六、安装与示例

v1 本地目录安装：把插件目录放进 `~/Library/Application Support/mpet/plugins/<name>/`，含 `plugin.json` 与入口文件。

本仓库 `examples/plugins/` 有两个完整示例：

- **`weather/`** — sense 型：定时上报环境感知（ambient）
- **`dice/`** — tool 型：stdin 读 `tool.call`、stdout 回 `tool.result`

把它们拷进插件目录就能跑。装的那一刻，你的宠物会拆礼物——别错过它的反应。
