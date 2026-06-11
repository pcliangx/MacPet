// Sources/mpet-cc-watcher/main.swift
import Foundation
import SoulCore

let args = CommandLine.arguments.dropFirst()

let supportDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/mpet")
let spoolDir = supportDir.appendingPathComponent("plugins/cc-watcher/spool")
let sockPath = supportDir.appendingPathComponent("soul.sock")
let settingsPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".claude/settings.json")

try? FileManager.default.createDirectory(at: spoolDir, withIntermediateDirectories: true)

// ── Hook install/uninstall ──
if args.contains("--install-hook") {
    let installer = HookInstaller(settingsPath: settingsPath)
    let hookCmd = "cat > \"\(spoolDir.path)/$(date +%s%3N).json\""
    try installer.install(hookCommand: hookCmd)
    print("✅ CC hook 已安装 → \(settingsPath.path)")
    print("   spool 目录：\(spoolDir.path)")
    exit(0)
}

if args.contains("--uninstall-hook") {
    let installer = HookInstaller(settingsPath: settingsPath)
    try installer.uninstall()
    print("✅ CC hook 已卸载")
    exit(0)
}

// ── Main loop: connect soul.sock + monitor spool ──
let client = SoulClient(socketPath: sockPath.path)
let monitor = CCSpoolMonitor(spoolDir: spoolDir)

await monitor.setHandler { event in
    let percept = event.toPercept()
    Task { await client.send(.senseEvent(percept)) }
    print("📡 CC: \(event.hookEventName) → \(percept.kind) (\(percept.priority.rawValue))")
}

await client.setMessageHandler { msg in
    switch msg {
    case .helloOK(_, let v):
        print("connected to soul v\(v)")
    case .actionInvoke(_, let actionId):
        if actionId == "return-to-cc" {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = ["-a", "Terminal"]
            try? proc.run()
            print("🎯 affordance: 带你回 CC 终端")
        }
    default: break
    }
}

await client.connect()
await client.performHandshake()
await monitor.start()

print("mpet-cc-watcher \(SoulCoreInfo.version) ｜ spool=\(spoolDir.lastPathComponent) ｜ soul.sock=\(sockPath.lastPathComponent)")
fflush(stdout)

await withUnsafeContinuation { (_: UnsafeContinuation<Void, Never>) in }
