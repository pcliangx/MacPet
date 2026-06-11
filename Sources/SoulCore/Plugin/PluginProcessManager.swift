import Foundation

/// M9 插件进程管理（spec §10.3）：拉起/握手/心跳/崩溃重启（不连坐）/一键停用
public actor PluginProcessManager {
    public struct PluginState: Sendable {
        public let manifest: PluginManifest
        public var status: Status
        public var restartCount: Int = 0
        public enum Status: String, Sendable { case stopped, starting, running, crashed, disabled }
    }

    private var plugins: [String: PluginState] = [:]
    private var processes: [String: Process] = [:]
    public static let maxRestarts = 3

    public init() {}

    /// 注册插件（不启动）
    public func register(manifest: PluginManifest) {
        plugins[manifest.name] = PluginState(manifest: manifest, status: .stopped)
    }

    /// 启动插件进程（exec 型）
    public func start(name: String, workingDirectory: URL? = nil) -> Bool {
        guard var state = plugins[name], state.status != .disabled else { return false }
        guard state.manifest.entry.type == "exec" else { return false }
        state.status = .starting
        plugins[name] = state

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", state.manifest.entry.cmd]
        if let wd = workingDirectory { proc.currentDirectoryURL = wd }
        proc.terminationHandler = { [weak self] _ in
            Task { await self?.handleTermination(name: name) }
        }
        do {
            try proc.run()
            processes[name] = proc
            state.status = .running
            plugins[name] = state
            return true
        } catch {
            state.status = .crashed
            plugins[name] = state
            return false
        }
    }

    /// 进程退出处理：崩溃重启策略（最多 maxRestarts 次，超过则停用）
    private func handleTermination(name: String) {
        guard var state = plugins[name] else { return }
        processes.removeValue(forKey: name)
        guard state.status == .running else { return }  // 主动停止的不算崩溃
        state.restartCount += 1
        if state.restartCount > Self.maxRestarts {
            state.status = .disabled  // 崩太多 → 自动停用（不连坐其他插件）
        } else {
            state.status = .crashed
        }
        plugins[name] = state
    }

    /// 停止插件
    public func stop(name: String) {
        guard var state = plugins[name] else { return }
        state.status = .stopped
        plugins[name] = state
        processes[name]?.terminate()
        processes.removeValue(forKey: name)
    }

    /// 一键停用（用户手动禁用）
    public func disable(name: String) {
        stop(name: name)
        guard var state = plugins[name] else { return }
        state.status = .disabled
        plugins[name] = state
    }

    /// 重新启用
    public func enable(name: String) {
        guard var state = plugins[name], state.status == .disabled else { return }
        state.status = .stopped
        state.restartCount = 0
        plugins[name] = state
    }

    public func status(of name: String) -> PluginState.Status? { plugins[name]?.status }
    public func restartCount(of name: String) -> Int { plugins[name]?.restartCount ?? 0 }
    public var registeredCount: Int { plugins.count }
    public func allPlugins() -> [PluginState] { Array(plugins.values) }
}
