import Foundation

/// macOS LaunchAgent plist 生成与安装（spec §5.1：launchd 自启）
public enum LaunchdInstaller {
    public static let defaultLabel = "com.mpet.soul"
    public static let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents")

    public static func generatePlist(
        label: String = defaultLabel,
        programPath: String,
        workingDirectory: String? = nil,
        keepAlive: Bool = true,
        runAtLoad: Bool = true
    ) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(programPath)</string>
            </array>
        """
        if let wd = workingDirectory {
            xml += "\n    <key>WorkingDirectory</key>\n    <string>\(wd)</string>"
        }
        if keepAlive { xml += "\n    <key>KeepAlive</key>\n    <true/>" }
        if runAtLoad { xml += "\n    <key>RunAtLoad</key>\n    <true/>" }
        xml += """

            <key>StandardOutPath</key>
            <string>/tmp/mpet-soul.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/mpet-soul.err</string>
        </dict>
        </plist>
        """
        return xml
    }

    public static func install(
        label: String = defaultLabel,
        programPath: String,
        plistDestination: URL? = nil
    ) throws {
        let dest = plistDestination ?? launchAgentsDir.appendingPathComponent("\(label).plist")
        try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        let plist = generatePlist(label: label, programPath: programPath)
        try plist.write(to: dest, atomically: true, encoding: .utf8)
        if plistDestination == nil {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            proc.arguments = ["load", "-w", dest.path]
            try? proc.run(); proc.waitUntilExit()
        }
    }

    public static func uninstall(plistPath: URL? = nil, skipLaunchctl: Bool = false) throws {
        let path = plistPath ?? launchAgentsDir.appendingPathComponent("\(defaultLabel).plist")
        if !skipLaunchctl && FileManager.default.fileExists(atPath: path.path) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            proc.arguments = ["unload", path.path]
            try? proc.run(); proc.waitUntilExit()
        }
        try? FileManager.default.removeItem(at: path)
    }
}
