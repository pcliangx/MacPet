# M9 它收到了礼物 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** 插件标准对外开放：manifest 解析与校验 + 权限确认模型 + 插件进程管理 + MCP 桥 + 礼物仪式 + 示例插件 ×2 + 第三方开发文档——任何人都能给它写插件了。

**Architecture:** `PluginManifest`（plugin.json 解析+校验）+ `PluginPermissions`（权限模型+确认流）+ `PluginProcessManager`（拉起/握手/心跳/崩溃重启）+ `MCPBridge`（MCP server→外设协议桥接模型）+ `GiftCeremony`（拆礼物仪式）+ 示例插件（weather sense + dice tool）+ `docs/PLUGIN-GUIDE.md`。

**对应 spec：** §10.2 manifest · §10.4 MCP 桥 · §10.5 权限与安全 · §10.6 分寸 · §10.7 礼物仪式 · §10.8 门控 · §10 整体对外开放。

---

## 文件结构

```
Sources/SoulCore/
  Plugin/PluginManifest.swift        # NEW: plugin.json 解析+校验
  Plugin/PluginPermissions.swift     # NEW: 权限模型+授权存储
  Plugin/PluginProcessManager.swift  # NEW: 进程生命周期
  Plugin/MCPBridge.swift             # NEW: MCP 桥接模型
  Plugin/GiftCeremony.swift          # NEW: 礼物仪式
examples/plugins/
  weather/plugin.json + weather.sh   # NEW: sense 示例
  dice/plugin.json + dice.sh         # NEW: tool 示例
docs/PLUGIN-GUIDE.md                 # NEW: 第三方开发文档
Tests/SoulCoreTests/
  PluginManifestTests.swift
  PluginPermissionsTests.swift
  PluginProcessManagerTests.swift
  MCPBridgeTests.swift
  GiftCeremonyTests.swift
```

### Task 0: PluginManifest — plugin.json 解析、kind/entry/permissions/tools/senses 校验、tier 申领限制（never 不可申领）
### Task 1: PluginPermissions — 权限枚举（network/read:path/notify/fuel）+ 授权记录持久化 + 喂养权单独确认
### Task 2: PluginProcessManager — 拉起 exec 插件、hello 握手、ping 心跳、崩溃重启策略（不连坐）、一键停用
### Task 3: MCPBridge — MCP tools/list → ToolSpec 映射（默认 ask 级）、notifications → ambient 感官
### Task 4: GiftCeremony — 拆礼物台词 + 玩具昵称（persona_hints）+ 当晚日记素材
### Task 5: 示例插件 ×2 + PLUGIN-GUIDE.md
### Task 6: DaemonSoul M9 集成 + 终验收 + 打标 v1.0.0-m9
