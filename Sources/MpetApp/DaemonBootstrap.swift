import Foundation
import SoulCore

/// .app 形态自举：把内嵌的 mpet-soul / mpet-cc-watcher 拷到 Application Support，
/// 配置就绪时自动安装 LaunchAgent——用户视角只有一个 App。
enum DaemonBootstrap {
    static let supportDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/mpet")
    static var binDir: URL { supportDir.appendingPathComponent("bin") }
    static var daemonDest: URL { binDir.appendingPathComponent("mpet-soul") }
    static var watcherDest: URL { binDir.appendingPathComponent("mpet-cc-watcher") }
    static var configPath: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/mpet/soul.json")
    }

    /// App 启动时调用。返回给用户看的提示（nil = 灵魂已就绪）。
    @discardableResult
    static func bootstrap() -> String? {
        copyEmbeddedBinaries()
        guard hasLLMConfig else {
            return "还没配置 LLM 端点～写 ~/.config/mpet/soul.json 后重启我"
        }
        if !isDaemonListening {
            try? LaunchdInstaller.install(programPath: daemonDest.path)
        }
        return nil
    }

    static var hasLLMConfig: Bool {
        if FileManager.default.fileExists(atPath: configPath.path) { return true }
        return ProcessInfo.processInfo.environment["MPET_BASE_URL"] != nil
    }

    /// 把 bundle Resources 里的二进制拷出去（LaunchAgent 指向稳定路径，App 移动不破）
    static func copyEmbeddedBinaries() {
        try? FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        for (name, dest) in [("mpet-soul", daemonDest), ("mpet-cc-watcher", watcherDest)] {
            guard let src = Bundle.main.url(forResource: name, withExtension: nil) else { continue }
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: src, to: dest)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)
        }
    }

    static var isDaemonListening: Bool {
        FileManager.default.fileExists(atPath: supportDir.appendingPathComponent("soul.sock").path)
    }
}
