import SwiftUI
import SoulCore

/// 镜像 mpet-soul 的 SoulConfig（SoulCore 不暴露此类型），仅用于读取同一配置文件。
private struct MpetSoulConfig: Codable {
    struct LLM: Codable {
        var baseURL: URL
        var apiKey: String
        var model: String
    }
    var llm: LLM
    var watchedBundleIDs: [String] = []
    var nudgeBudgetPerHour: Int = 4

    static var path: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/mpet/soul.json")
    }
    static func load() throws -> MpetSoulConfig {
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(MpetSoulConfig.self, from: data)
    }
}

struct SettingsPanel: View {
    @ObservedObject var viewModel: PetViewModel
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var nudgeBudget = 4
    @State private var statusMessage = ""

    var body: some View {
        Form {
            Section("LLM 端点") {
                TextField("Base URL", text: $baseURL)
                SecureField("API Key", text: $apiKey)
                TextField("Model", text: $model)
                Button("保存到 Keychain") { saveAPIKey() }
            }
            Section("人设") {
                Stepper("唤醒预算：\(nudgeBudget)/小时", value: $nudgeBudget, in: 1...20)
            }
            Section("守护进程") {
                HStack {
                    Button("安装 LaunchAgent") { installLaunchd() }
                    Button("卸载") { uninstallLaunchd() }
                }
            }
            Section("CC Watcher") {
                HStack {
                    Button("安装 CC Hook") { installCCHook() }
                    Button("卸载") { uninstallCCHook() }
                }
            }
            if !statusMessage.isEmpty {
                Text(statusMessage).foregroundStyle(.secondary).font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 400)
        .onAppear { loadSettings() }
    }

    private func loadSettings() {
        apiKey = KeychainStore().load(account: "apiKey") ?? ""
        if let config = try? MpetSoulConfig.load() {
            baseURL = config.llm.baseURL.absoluteString
            model = config.llm.model
            nudgeBudget = config.nudgeBudgetPerHour
        }
    }
    private func saveAPIKey() {
        let ok = KeychainStore().save(apiKey, account: "apiKey")
        statusMessage = ok ? "✅ API Key 已保存到 Keychain" : "❌ 保存失败"
    }
    private func installLaunchd() {
        let binPath = "/usr/local/bin/mpet-soul"
        do { try LaunchdInstaller.install(programPath: binPath); statusMessage = "✅ LaunchAgent 已安装" }
        catch { statusMessage = "❌ 安装失败: \(error)" }
    }
    private func uninstallLaunchd() {
        do { try LaunchdInstaller.uninstall(); statusMessage = "✅ LaunchAgent 已卸载" }
        catch { statusMessage = "❌ 卸载失败: \(error)" }
    }
    private func installCCHook() {
        let sp = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
        let spoolDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/mpet/plugins/cc-watcher/spool")
        try? FileManager.default.createDirectory(at: spoolDir, withIntermediateDirectories: true)
        let hookCmd = "cat > \"\(spoolDir.path)/$(date +%s%3N).json\""
        do { try HookInstaller(settingsPath: sp).install(hookCommand: hookCmd); statusMessage = "✅ CC Hook 已安装" }
        catch { statusMessage = "❌ 安装失败: \(error)" }
    }
    private func uninstallCCHook() {
        let sp = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
        do { try HookInstaller(settingsPath: sp).uninstall(); statusMessage = "✅ CC Hook 已卸载" }
        catch { statusMessage = "❌ 卸载失败: \(error)" }
    }
}
