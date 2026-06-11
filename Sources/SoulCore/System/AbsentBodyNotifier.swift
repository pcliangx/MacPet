import Foundation

/// M2 身体缺席降级（spec §5.1："守望类插件的关键提醒走系统通知兜底"）
public enum AbsentBodyNotifier {
    public static func shouldNotify(priority: PerceptPriority, bodyConnected: Bool) -> Bool {
        !bodyConnected && priority == .alert
    }
    public static func buildCommand(title: String, body: String, subtitle: String = "mpet") -> String {
        let e = { (s: String) -> String in s.replacingOccurrences(of: "\"", with: "\\\"") }
        return "osascript -e 'display notification \"\(e(body))\" with title \"\(e(title))\" subtitle \"\(e(subtitle))\"'"
    }
    public static func notify(title: String, body: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", buildCommand(title: title, body: body)]
        try? proc.run()
    }
}
