import Foundation

/// M9 插件权限模型（spec §10.5）：安装时逐条确认，喂养权单独一条。
public enum PluginPermission: Equatable, Sendable, Hashable {
    case network
    case readPath(String)
    case notify
    case fuel          // 喂养权（敏感，单独确认）

    public static func parse(_ raw: String) -> PluginPermission? {
        if raw == "network" { return .network }
        if raw == "notify" { return .notify }
        if raw == "fuel" { return .fuel }
        if raw.hasPrefix("read:") { return .readPath(String(raw.dropFirst(5))) }
        return nil
    }

    public var displayText: String {
        switch self {
        case .network: return "访问网络"
        case .readPath(let p): return "读取目录：\(p)"
        case .notify: return "发送系统通知"
        case .fuel: return "喂养权（上报口粮信号，影响成长）⚠️ 敏感权限"
        }
    }

    public var isSensitive: Bool { self == .fuel }

    var storageKey: String {
        switch self {
        case .network: return "network"
        case .readPath(let p): return "read:\(p)"
        case .notify: return "notify"
        case .fuel: return "fuel"
        }
    }
}

/// 授权记录（哪个插件被授予了哪些权限）
public final class PluginPermissionStore: @unchecked Sendable {
    private let dir: URL
    private let lock = NSLock()
    private var grants: [String: Set<String>] = [:]   // pluginName → granted permission keys
    private var fileURL: URL { dir.appendingPathComponent("plugin-permissions.json") }

    public init(directory: URL) {
        self.dir = directory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: fileURL),
           let g = try? JSONDecoder().decode([String: Set<String>].self, from: data) { grants = g }
    }

    public func grant(plugin: String, permission: PluginPermission) {
        lock.lock(); defer { lock.unlock() }
        grants[plugin, default: []].insert(permission.storageKey)
        save()
    }

    public func revoke(plugin: String, permission: PluginPermission) {
        lock.lock(); defer { lock.unlock() }
        grants[plugin]?.remove(permission.storageKey)
        save()
    }

    public func revokeAll(plugin: String) {
        lock.lock(); defer { lock.unlock() }
        grants.removeValue(forKey: plugin)
        save()
    }

    public func isGranted(plugin: String, permission: PluginPermission) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return grants[plugin]?.contains(permission.storageKey) ?? false
    }

    /// 解析 manifest 权限串并返回待确认列表（喂养权排最后单独展示）
    public static func pendingConfirmations(manifest: PluginManifest) -> [PluginPermission] {
        var perms = manifest.permissions.compactMap { PluginPermission.parse($0) }
        // 声明了 fuel kind 但 permissions 没写 fuel → 自动补
        if manifest.kind.contains("fuel") && !perms.contains(.fuel) { perms.append(.fuel) }
        // 喂养权排最后
        return perms.sorted { !$0.isSensitive && $1.isSensitive }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(grants) else { return }
        let tmp = dir.appendingPathComponent(".plugin-permissions.tmp")
        try? data.write(to: tmp, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
    }
}
