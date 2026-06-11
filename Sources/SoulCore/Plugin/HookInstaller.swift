// Sources/SoulCore/Plugin/HookInstaller.swift
import Foundation

/// CC settings.json hook 安装器：备份 → 注入 hook → 可卸载恢复。
///
/// 安装时替换 Notification 事件全部条目（备份保留原始内容）；
/// 卸载时移除 mpet 注入的 Notification 条目。
public struct HookInstaller {
    public let settingsPath: URL
    public init(settingsPath: URL) { self.settingsPath = settingsPath }

    public func install(hookCommand: String) throws {
        var settings = try loadSettings()
        removeMpetHooks(from: &settings)
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        let hookEntry: [String: Any] = [
            "hooks": [["type": "command", "command": hookCommand, "timeout": 5]]
        ]
        hooks["Notification"] = [hookEntry]
        settings["hooks"] = hooks
        try backup()
        try writeSettings(settings)
    }

    public func uninstall() throws {
        var settings = try loadSettings()
        removeMpetHooks(from: &settings)
        try writeSettings(settings)
    }

    private func loadSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsPath.path) else { return [:] }
        let data = try Data(contentsOf: settingsPath)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func writeSettings(_ settings: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        let tmp = settingsPath.deletingLastPathComponent().appendingPathComponent(".settings.tmp")
        try data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: settingsPath.path) {
            _ = try? FileManager.default.replaceItemAt(settingsPath, withItemAt: tmp)
        }
        if !FileManager.default.fileExists(atPath: settingsPath.path) {
            try FileManager.default.moveItem(at: tmp, to: settingsPath)
        }
    }

    private func backup() throws {
        guard FileManager.default.fileExists(atPath: settingsPath.path) else { return }
        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        let backup = settingsPath.deletingLastPathComponent()
            .appendingPathComponent("settings.json.backup-mpet-hook-\(stamp)")
        // Best-effort: silently skip if backup already exists (rapid re-install).
        try? FileManager.default.copyItem(at: settingsPath, to: backup)
    }

    /// 移除 mpet 管理的 Notification hook 条目。
    /// 因 install 整体替换 Notification 事件，此处直接清除该事件全部条目。
    private func removeMpetHooks(from settings: inout [String: Any]) {
        guard var hooks = settings["hooks"] as? [String: Any] else { return }
        hooks.removeValue(forKey: "Notification")
        settings["hooks"] = hooks
    }
}
